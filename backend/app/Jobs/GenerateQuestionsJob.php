<?php

namespace App\Jobs;

use App\Models\File;
use App\Models\Question;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GenerateQuestionsJob implements ShouldQueue
{
    use Queueable;

    public int $timeout = 0;
    public int $tries   = 1;

    const MODEL_URL     = 'http://172.164.240.4:8000';
    const NGROK_HEADERS = [
        'ngrok-skip-browser-warning' => 'true',
        'Accept'                     => 'application/json',
    ];
    const CHUNK_SIZE_MIN          = 1000;
    const CHUNK_SIZE_MAX          = 3000;
    const CHUNK_SIZE_BASE         = 2200;
    const MAX_CHUNKS              = 25;
    const QUESTIONS_PER_CHUNK_MAX = 4;

    public function __construct(
        public string  $fileId,
        public string  $userId,
        public string  $rawType,
        public string  $type,
        public string  $difficulty,
        public int     $count,
        public ?int    $fromPage,
        public ?int    $toPage,
    ) {}

    public function handle(): void
    {
        $file = File::where('user_id', $this->userId)
                    ->where('_id', $this->fileId)
                    ->first();

        if (!$file) {
            Cache::put("progress_{$this->fileId}", [
                'current' => 0, 'total' => 0,
                'status'  => 'failed', 'message' => 'File not found',
            ], 300);
            return;
        }

        $sourceData = !empty($file->pages) ? $file->pages : $file->extracted_text;
        if (empty($sourceData)) {
            Cache::put("progress_{$this->fileId}", [
                'current' => 0, 'total' => 0,
                'status'  => 'failed', 'message' => 'No text extracted',
            ], 300);
            return;
        }

        $rawText   = $this->extractPageRange($sourceData, $this->fromPage, $this->toPage);
        $cleanText = $this->cleanText($rawText);

        if (empty(trim($cleanText))) {
            Cache::put("progress_{$this->fileId}", [
                'current' => 0, 'total' => 0,
                'status'  => 'failed', 'message' => 'No usable text',
            ], 300);
            return;
        }

        $lang        = $this->detectLanguage($cleanText);
        $textLen     = mb_strlen($cleanText);
        $chunkSize   = $this->dynamicChunkSize($textLen, $this->count);
        $rawChunks   = array_values(array_filter(
            $this->chunkText($cleanText, $chunkSize),
            fn($c) => !$this->isUselessChunk($c)
        ));
        $totalChunks = count($rawChunks);

        if ($totalChunks === 0) {
            Cache::put("progress_{$this->fileId}", [
                'current' => 0, 'total' => 0,
                'status'  => 'failed', 'message' => 'No usable chunks',
            ], 300);
            return;
        }

        Cache::put("progress_{$this->fileId}", [
            'current' => 0, 'total' => $totalChunks,
            'status'  => 'running', 'message' => 'Starting...',
        ], 3600);

        $chunkMeta = [];
        foreach ($rawChunks as $i => $chunk) {
            $chunkMeta[$i] = [
                'examples' => $this->countSolvedExamples($chunk),
                'density'  => $this->contentDensity($chunk),
                'len'      => mb_strlen($chunk),
            ];
        }

        $budgets   = $this->redistributeBudget($this->count, $chunkMeta, $totalChunks);
        $allChunks = [];
        foreach ($rawChunks as $i => $chunk) {
            $allChunks[$i] = $i > 0
                ? mb_substr($rawChunks[$i - 1], -500) . "\n\n" . $chunk
                : $chunk;
        }

        $questionsArray = [];
        $seenHashes     = [];
        $maxRounds      = 5;
        $round          = 0;
        $usedSeeds      = [];
        $timestamp      = now()->timestamp;

        while (count($questionsArray) < $this->count && $round < $maxRounds) {
            $round++;
            $stillNeeded   = $this->count - count($questionsArray);
            $remainBudgets = $round === 1
                ? $budgets
                : $this->redistributeBudget($stillNeeded, $chunkMeta, $totalChunks);

            foreach ($allChunks as $chunkIndex => $chunk) {
                if (count($questionsArray) >= $this->count) break;

                $chunkBudget = $remainBudgets[$chunkIndex] ?? 0;
                if ($chunkBudget <= 0) continue;

                $requestedBatch = min($chunkBudget, self::QUESTIONS_PER_CHUNK_MAX);
                $meta           = $chunkMeta[$chunkIndex];

                do { $seed = rand(1, 999999); } while (in_array($seed, $usedSeeds));
                $usedSeeds[] = $seed;

                $prompt = $this->prompt('questions', [
                    'text'            => $chunk,
                    'count'           => $requestedBatch,
                    'type'            => $this->type,
                    'difficulty'      => $this->difficulty,
                    'chunk_index'     => $chunkIndex + 1,
                    'total_chunks'    => $totalChunks,
                    'seed'            => $seed,
                    'timestamp'       => $timestamp,
                    'language'        => $lang,
                    'solved_examples' => $meta['examples'],
                    'content_type'    => $meta['examples'] > 0 ? 'has_solved_examples' : 'theory_only',
                ]);

                $temperature = min(0.3 + ($round * 0.05), 0.7);
                $part        = $this->callModelWithRetry($prompt, 'qa', $temperature);
                if ($part === null) continue;

                Cache::put("progress_{$this->fileId}", [
                    'current' => $chunkIndex + 1,
                    'total'   => $totalChunks,
                    'status'  => 'running',
                    'message' => 'Processing chunk ' . ($chunkIndex + 1) . ' of ' . $totalChunks,
                ], 3600);

                $part = $this->normalizeToMarkdown($part);
                if (!preg_match('/##\s*Question\s*\d+/i', $part)) continue;

                $part         = trim(preg_replace('/^.*?(##\s*Question\s*\d+)/is', '$1', $part));
                $newQuestions = $this->splitIntoIndividualQuestions($part);

                foreach ($newQuestions as $q) {
                    if (count($questionsArray) >= $this->count) break;
                    $hash = md5(preg_replace('/\s+/', ' ', strtolower(strip_tags($q))));
                    if (isset($seenHashes[$hash])) continue;
                    $seenHashes[$hash] = true;
                    $questionsArray[]  = $q;
                }
            }
        }

        if (empty($questionsArray)) {
            Cache::put("progress_{$this->fileId}", [
                'current' => 0, 'total' => $totalChunks,
                'status'  => 'failed', 'message' => 'Model failed to generate questions',
            ], 300);
            return;
        }

        $questionsArray = array_slice($questionsArray, 0, $this->count);
        $questionsArray = array_map(fn($seg) => trim(preg_replace('/##QSEP##/i', '', $seg)), $questionsArray);
        $questionsArray = array_map(function ($seg, $idx) {
            return preg_replace('/##\s*Question\s*\d+/i', '## Question ' . ($idx + 1), $seg, 1);
        }, $questionsArray, array_keys($questionsArray));

        $content     = trim(implode("\n\n##QSEP##\n\n", $questionsArray));
        $actualCount = count($questionsArray);

        Question::create([
            'user_id'    => $this->userId,
            'file_id'    => $this->fileId,
            'question'   => $content,
            'type'       => $this->rawType,
            'difficulty' => $this->difficulty,
            'count'      => $actualCount,
        ]);

        Cache::put("progress_{$this->fileId}", [
            'current'      => $totalChunks,
            'total'        => $totalChunks,
            'status'       => 'done',
            'message'      => 'Questions complete',
            'result'       => $content,
            'actual_count' => $actualCount,
        ], 300);
    }

    // ── Helpers ──────────────────────────────────────────────

    private function extractPageRange($pagesData, $pageFrom, $pageTo): string
    {
        if (is_string($pagesData)) {
            $decoded = json_decode($pagesData, true);
            if (is_array($decoded)) $pagesData = $decoded;
        }
        if (is_array($pagesData)) {
            if (empty($pagesData)) return '';
            $from        = max(1, (int)($pageFrom ?? 1));
            $to          = min(count($pagesData), (int)($pageTo ?? count($pagesData)));
            if ($from > $to) return '';
            $slicedPages = array_slice($pagesData, $from - 1, $to - $from + 1);
            $textChunks  = array_map(function ($page) {
                if (is_array($page) && isset($page['text'])) return $page['text'];
                return is_string($page) ? $page : '';
            }, $slicedPages);
            return implode("\n\n", array_filter($textChunks));
        }
        return is_string($pagesData) ? trim($pagesData) : '';
    }

    private function cleanText(string $text): string
    {
        $text = preg_replace('/[^\x{0020}-\x{007E}\x{00A0}-\x{024F}\x{0600}-\x{06FF}\x{0750}-\x{077F}\n\r\t]/u', ' ', $text);
        $text = strip_tags($text);
        $text = preg_replace('/[^\S\n]+/', ' ', $text);
        $text = preg_replace('/^#{1,6}\s*$/m', '', $text);
        $text = preg_replace('/\n{3,}/', "\n\n", $text);
        $text = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $text);
        return trim($text);
    }

    private function detectLanguage(string $text): string
    {
        $sample = mb_substr($text, 0, 2000);
        preg_match_all('/[\x{0600}-\x{06FF}]/u', $sample, $ar);
        preg_match_all('/[A-Za-z]/', $sample, $en);
        $total   = max(1, count($ar[0]) + count($en[0]));
        $arRatio = count($ar[0]) / $total;
        if ($arRatio >= 0.75) return 'arabic';
        if ($arRatio <= 0.25) return 'english';
        return 'mixed';
    }

    private function dynamicChunkSize(int $textLen, int $questionCount): int
    {
        $base = self::CHUNK_SIZE_BASE;
        if ($questionCount === 0) {
            $size = $base;
        } else {
            $neededChunks = max(1, (int) ceil($questionCount / self::QUESTIONS_PER_CHUNK_MAX));
            $idealSize    = (int) ceil($textLen / $neededChunks);
            $size         = max((int)($base * 0.6), min($idealSize, (int)($base * 1.2)));
        }
        $size            = max(self::CHUNK_SIZE_MIN, min($size, self::CHUNK_SIZE_MAX));
        $estimatedChunks = (int) ceil($textLen / $size);
        if ($estimatedChunks > self::MAX_CHUNKS)
            $size = min((int) ceil($textLen / self::MAX_CHUNKS), self::CHUNK_SIZE_MAX);
        return $size;
    }

    private function chunkText(string $text, int $maxChars): array
    {
        $TARGET    = $maxChars;
        $MIN_CHUNK = (int)($maxChars * 0.4);
        $MAX_CHUNK = (int)($maxChars * 1.2);
        $chunks    = [];
        $text      = trim($text);
        while (mb_strlen($text) > $TARGET) {
            $splitAt = false;
            $window  = mb_substr($text, $MIN_CHUNK, $TARGET - $MIN_CHUNK);
            if (preg_match('/\n(?=#{1,6}\s)/u', $window, $m, PREG_OFFSET_CAPTURE))
                $splitAt = $MIN_CHUNK + $m[0][1];
            if ($splitAt === false) {
                $pos = mb_strrpos(mb_substr($text, 0, $TARGET), "\n\n");
                if ($pos !== false && $pos >= $MIN_CHUNK) $splitAt = $pos;
            }
            if ($splitAt === false) {
                $pos = mb_strrpos(mb_substr($text, 0, $TARGET), "\n");
                if ($pos !== false && $pos >= $MIN_CHUNK) $splitAt = $pos;
            }
            if ($splitAt === false || $splitAt > $MAX_CHUNK) $splitAt = $MAX_CHUNK;
            $chunk = trim(mb_substr($text, 0, $splitAt));
            if ($chunk !== '') $chunks[] = $chunk;
            $text = trim(mb_substr($text, $splitAt));
        }
        if ($text !== '') $chunks[] = $text;
        return $chunks;
    }

    private function isUselessChunk(string $chunk): bool
    {
        $trimmed = trim($chunk);
        if (mb_strlen($trimmed) < 50) return true;
        if (preg_match('/```[\s\S]{10,}```/u', $trimmed)) return false;
        preg_match_all('/[\$\=\+\-\*\/\^\{\}\(\)\[\]]/', $trimmed, $mathMatches);
        if (count($mathMatches[0]) > 15) return false;
        $lines        = preg_split('/\n/', $trimmed);
        $numericLines = array_filter($lines, fn($l) => preg_match('/^\s*[\d\.]+\s*$/', trim($l)));
        if (count($lines) > 5 && count($numericLines) / count($lines) > 0.5) return true;
        $uselessHeaders = ['bibliography', 'references', 'index', 'table of contents', 'المراجع', 'قائمة المراجع', 'الفهرس', 'المحتويات'];
        $firstLine = mb_strtolower(mb_substr($trimmed, 0, 80));
        foreach ($uselessHeaders as $h) {
            if (str_contains($firstLine, $h)) return true;
        }
        return false;
    }

    private function countSolvedExamples(string $chunk): int
    {
        preg_match_all('/\b(Example|Solution|Proof|Theorem|مثال|حل\s|برهان|نظرية)\b/ui', $chunk, $m);
        return (int) floor(count($m[0]) / 2);
    }

    private function contentDensity(string $chunk): float
    {
        $len          = mb_strlen($chunk);
        $exampleBonus = $this->countSolvedExamples($chunk) * 500;
        preg_match_all('/[\$\=\+\-\*\/\^\{\}\(\)\[\]]/', $chunk, $mathMatches);
        $mathScore = min(count($mathMatches[0]) * 2, 1000);
        return max(1.0, ($len + $exampleBonus + $mathScore) / 1000.0);
    }

    private function redistributeBudget(int $needed, array $chunkMeta, int $totalChunks): array
    {
        $totalDensity = max(1, array_sum(array_column($chunkMeta, 'density')));
        $budgets      = [];
        $assigned     = 0;
        foreach ($chunkMeta as $i => $meta) {
            $share       = (int) round($needed * ($meta['density'] / $totalDensity));
            $budgets[$i] = max(1, $share);
            $assigned   += $budgets[$i];
        }
        $diff = $needed - $assigned;
        if ($diff !== 0) {
            $keys = array_keys($chunkMeta);
            usort($keys, fn($a, $b) => $chunkMeta[$b]['density'] <=> $chunkMeta[$a]['density']);
            $budgets[$keys[0]] = max(1, ($budgets[$keys[0]] ?? 1) + $diff);
        }
        return $budgets;
    }

    private function callModelWithRetry(string $prompt, string $task, float $temperature, int $maxRetries = 2): ?string
    {
        for ($attempt = 0; $attempt <= $maxRetries; $attempt++) {
            try {
                $response = Http::withHeaders(self::NGROK_HEADERS)
                    ->timeout(0)
                    ->post(self::MODEL_URL . '/generate', [
                        'prompt'      => $prompt,
                        'task'        => $task,
                        'temperature' => $temperature,
                    ]);
                if (!$response->successful()) {
                    if ($response->status() === 404) return null;
                    if ($attempt < $maxRetries) sleep($response->status() === 503 ? 60 : 2);
                    continue;
                }
                $part = trim($response->json('response') ?? '');
                if (empty($part)) {
                    if ($attempt < $maxRetries) sleep(2);
                    continue;
                }
                if ($this->isRepetitive($part)) {
                    if ($attempt < $maxRetries) sleep(2);
                    continue;
                }
                $part = preg_replace('/[\x{4E00}-\x{9FFF}\x{3040}-\x{30FF}\x{AC00}-\x{D7AF}]+/u', '', $part);
                $part = preg_replace('/[^\S\n]+/', ' ', $part);
                $part = preg_replace('/\n{3,}/', "\n\n", $part);
                $part = preg_replace('/^(?:النص|النص الأصلي|Original Text|Text)\s*:[^\n]*\n?/mu', '', $part);
                $part = preg_replace('/^#{1,4}\s+(.+)$/mu', '**$1**', $part);
                return trim($part);
            } catch (\Exception $e) {
                Log::warning("Job model call exception (attempt {$attempt}): " . $e->getMessage());
                if ($attempt < $maxRetries) sleep(pow(2, $attempt + 1));
            }
        }
        return null;
    }

    private function isRepetitive(string $text): bool
    {
        return (bool) preg_match('/(\b\w+\b)(\s+\1){10,}/i', $text);
    }

    private function normalizeToMarkdown(string $raw): string
    {
        $clean = preg_replace('/^```[\w]*\s*/m', '', $raw);
        $clean = preg_replace('/```\s*$/m', '', $clean);
        $clean = trim($clean);
        $clean = preg_replace('/^###\s*Question\s*(\d+)/mi', '## Question $1', $clean);
        $clean = preg_replace('/^\*{1,2}Question\s*(\d+)[:\.]?\*{0,2}/mi', '## Question $1', $clean);
        $clean = preg_replace('/^###\s*(Type|Difficulty|Topic|Question):[^\n]*/mi', '', $clean);
        $clean = preg_replace('/^-{3,}\s*$/mi', '##QSEP##', $clean);
        if (trim($clean) !== '' && !preg_match('/#{0,2}QSEP##\s*$/i', trim($clean)))
            $clean = rtrim($clean) . "\n##QSEP##";
        $clean = preg_replace('/\n{3,}/', "\n\n", $clean);
        return trim($clean);
    }

    private function splitIntoIndividualQuestions(string $blob): array
    {
        $parts = preg_split('/\n?\s*#{0,2}QSEP##\s*\n?/i', $blob);
        $parts = array_values(array_filter(array_map('trim', $parts)));
        $valid = array_values(array_filter($parts, fn($s) => (bool) preg_match('/##\s*Question\s*\d+/i', $s)));
        if (empty($valid)) {
            $raw   = preg_split('/(?=##\s*Question\s*\d+)/i', $blob);
            $valid = array_values(array_filter(array_map('trim', $raw), fn($s) => (bool) preg_match('/##\s*Question\s*\d+/i', $s)));
        }
        $valid = array_map(fn($s) => trim(preg_replace('/#{0,2}QSEP##/i', '', $s)), $valid);
        $valid = array_values(array_filter($valid, fn($s) => trim(preg_replace('/##\s*Question\s*\d+[^\n]*\n?/i', '', $s, 1)) !== ''));
        return $valid;
    }

    private function prompt(string $name, array $data = []): string
    {
        $path = base_path("prompts/{$name}.md");
        if (!file_exists($path)) return "Generate {$name} from:\n\n" . ($data['text'] ?? '');
        $content = file_get_contents($path);
        if ($name === 'questions' && isset($data['type'])) {
            $data['few_shot_example']  = '';
            $data['type_instructions'] = '';
        }
        foreach ($data as $key => $value) {
            $content = str_replace('{{' . $key . '}}', (string) $value, $content);
        }
        return preg_replace('/\{\{[a-z_]+\}\}/', '', $content);
    }
}
