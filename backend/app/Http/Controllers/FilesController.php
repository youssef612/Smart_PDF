<?php

namespace App\Http\Controllers;

use App\Models\File;
use App\Models\Summary;
use App\Models\Question;
use App\Models\Explanation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Validation\Rule;

class FilesController extends Controller
{
    const MARKER_URL    = 'https://ponchoed-cloddishly-tamekia.ngrok-free.dev';
    const MODEL_URL     = 'https://botany-symphonic-essential.ngrok-free.dev';
    const NGROK_HEADERS = [
        'ngrok-skip-browser-warning' => 'true',
        'Accept'                     => 'application/json',
    ];

    const CHUNK_SIZE_MIN          = 1000;
    const CHUNK_SIZE_MAX          = 3000;
    const CHUNK_SIZE_BASE         = 2200;
    const MAX_CHUNKS              = 25;
    const QUESTIONS_PER_CHUNK_MAX = 4;

    // ────────────────────────────────────────────────────────
    //  GET /files
    // ────────────────────────────────────────────────────────
    public function recent()
    {
        if (!auth()->check()) {
            return response()->json(['success' => true, 'data' => []]);
        }

        $files = File::where('user_id', (string) auth()->id())
            ->latest()->take(10)->get();

        return response()->json([
            'success' => true,
            'data'    => $files->map(fn($f) => $this->formatFile($f)),
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /files/upload
    // ────────────────────────────────────────────────────────
    private function calculatePageCount(array $data): int
    {
        // 1. جرب page_count من API أولاً (الأهم)
        if (!empty($data['page_count'])) {
            return (int)$data['page_count'];
        }

        // 2. جرب pages كـ array
        if (!empty($data['pages']) && is_array($data['pages'])) {
            return count($data['pages']);
        }

        // 3. جرب pages كـ JSON string
        if (!empty($data['pages']) && is_string($data['pages'])) {
            $decoded = json_decode($data['pages'], true);
            if (is_array($decoded)) {
                return count($decoded);
            }
        }

        // 4. احسب من النص (Fallback فقط)
        if (!empty($data['full_text'])) {
            $textLen = mb_strlen($data['full_text']);
            return max(1, (int)ceil($textLen / 1500)); // 1500 بدل 2500
        }

        return 1;
    }
    
    public function upload(Request $request)
    {
        set_time_limit(0);
        $request->validate(['file' => 'required|file|mimes:pdf|max:204800']);

        $uploadedFile = $request->file('file');
        $userId = auth()->id();
        $fileHash = hash_file('sha256', $uploadedFile->getRealPath());

        // تحقق من التكرار
        $existingFile = File::where('user_id', (string) $userId)
            ->where('file_hash', $fileHash)
            ->first();

        if ($existingFile) {
            return response()->json([
                'success' => true,
                'message' => 'File already uploaded',
                'data'    => $this->formatFile($existingFile),
                'isExisting' => true,
            ], 200);
        }

        $folder = $userId ? 'pdfs/' . $userId : 'pdfs/guest';
        $path = $uploadedFile->store($folder, 'public');

        if ($path === false) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to store file',
            ], 500);
        }

        $savedFile = File::create([
            'user_id'      => $userId ? (string) $userId : null,
            'file_name'    => $uploadedFile->getClientOriginalName(),
            'file_type'    => 'PDF',
            'file_path'    => $path,
            'file_hash'    => $fileHash,
            'size'         => $uploadedFile->getSize(),
            'status'       => 'Extracting',
            'uploaded_at'  => now(),
        ]);

        try {
            $fullPath = storage_path('app/public/' . $path);
            
            // ✅ تحقق من وجود الملف
            if (!file_exists($fullPath)) {
                throw new \Exception("File not found at: $fullPath");
            }

            $response = Http::withHeaders(self::NGROK_HEADERS)
                ->timeout(0)
                ->attach('file', file_get_contents($fullPath), $uploadedFile->getClientOriginalName())
                ->post(self::MARKER_URL . '/extract');

            if (!$response->successful()) {
                $savedFile->update(['status' => 'ExtractionFailed']);
                return response()->json([
                    'success' => false,  // ✅ غيّر
                    'message' => 'File saved but extraction failed',
                    'data'    => $this->formatFile($savedFile->fresh()),
                    'has_text' => false,
                ], 422);
            }

            $data = $response->json();
            if (!empty($data['full_text'])) {
                Log::info('API Pages Debug:', [
                    'pages_type' => gettype($data['pages']),
                    'pages_is_string' => is_string($data['pages']),
                    'pages_sample' => is_string($data['pages']) ? substr($data['pages'], 0, 200) : 'N/A',
                ]);

                $calculatedPageCount = $this->calculatePageCount($data);
                
                Log::info('Calculated Page Count: ' . $calculatedPageCount);
                $savedFile->update([
                    'pages'          => $data['pages'],
                    'extracted_text' => $data['full_text'],
                    'page_count'     => $calculatedPageCount,
                    'status'         => 'Ready',
                ]);
                return response()->json([
                    'success' => true,
                    'message' => 'File uploaded successfully',
                    'data'    => $this->formatFile($savedFile->fresh()),
                    'has_text' => true,
                ], 200);
            }

            $jobId = $data['job_id'] ?? null;
            if ($jobId) {
                \App\Jobs\PollExtractionJob::dispatch((string) $savedFile->id, $jobId);
                return response()->json([
                    'success' => true,
                    'message' => 'File uploaded, extraction in progress',
                    'data'    => $this->formatFile($savedFile->fresh()),
                    'has_text' => false,
                ], 200);
            }

            $savedFile->update(['status' => 'ExtractionFailed']);
            return response()->json([
                'success' => false,  // ✅ غيّر
                'message' => 'File saved but no job ID returned',
                'data'    => $this->formatFile($savedFile->fresh()),
                'has_text' => false,
            ], 422);

        } catch (\Exception $e) {
            Log::error("Upload error for file {$savedFile->id}: " . $e->getMessage());
            $savedFile->update(['status' => 'ExtractionFailed']);
            return response()->json([
                'success' => false,  // ✅ غيّر
                'message' => 'File saved but extraction failed',
                'data'    => $this->formatFile($savedFile->fresh()),
                'has_text' => false,
            ], 500);
        }
    }
    
    // ────────────────────────────────────────────────────────
    //  GET /files/history
    // ────────────────────────────────────────────────────────
    public function getHistory()
    {
        $files = File::where('user_id', (string) auth()->id())
            ->orderBy('uploaded_at', 'desc')->get();

        return response()->json([
            'success' => true,
            'data'    => $files->map(fn($f) => $this->formatFile($f)),
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  GET /files/{id}/download
    // ────────────────────────────────────────────────────────
    public function download($id)
    {
        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found'], 404);
        }
        if (empty($file->file_path) || !Storage::disk('public')->exists($file->file_path)) {
            return response()->json(['success' => false, 'message' => 'File not found on disk'], 404);
        }
        $fullPath = Storage::disk('public')->path($file->file_path);
        return response()->download($fullPath, $file->file_name, ['Content-Type' => 'application/pdf']);
    }

    // ────────────────────────────────────────────────────────
    //  GET /files/{id}/details
    // ────────────────────────────────────────────────────────
    public function getFileDetails($id)
    {
        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }
        return response()->json(['success' => true, 'data' => $this->formatFile($file)]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /files/{id}/summarize
    // ────────────────────────────────────────────────────────
    public function summarize(Request $request, $id)
    {
        set_time_limit(0);

        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        if (empty($file->extracted_text)) {
            return response()->json(['success' => false, 'message' => 'Text not extracted yet.'], 422);
        }

        $cleanText = $this->cleanText(
            $this->extractPageRange($file->extracted_text, $request->input('page_from'), $request->input('page_to'))
        );

        $lang      = $this->detectLanguage($cleanText);
        $chunkSize = $this->dynamicChunkSize(mb_strlen($cleanText), 0);
        $chunks    = $this->chunkText($cleanText, $chunkSize);
        $partials  = [];
        $timestamp = now()->timestamp;

        foreach ($chunks as $i => $chunk) {
            if ($this->isUselessChunk($chunk)) {
                Log::info("Summarize chunk {$i} identified as useless — skipped.");
                continue;
            }

            $prompt = $this->prompt('summarize', [
                'text'         => $chunk,
                'chunk_index'  => $i + 1,
                'total_chunks' => count($chunks),
                'language'     => $lang,
                'timestamp'    => $timestamp,
                'seed'         => rand(1, 99999),
            ]);

            $part = $this->callModelWithRetry($prompt, 'summarize', 0.3, null, 5);
            if ($part === null) continue;
            $partials[] = $part;
        }

        if (empty($partials)) {
            return response()->json(['success' => false, 'message' => 'Model failed to generate summary.'], 500);
        }
        $content = implode("\n\n---\n\n", $partials);


        Summary::create([
            'user_id' => (string) auth()->id(),
            'file_id' => (string) $file->id,
            'content' => $content,
        ]);

        return response()->json(['success' => true, 'data' => ['summary' => $content]]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /files/{id}/questions
    // ────────────────────────────────────────────────────────
    public function questions(Request $request, $id)
    {
        set_time_limit(0);

        $codeSubTypes = [
            'code_output', 'code_write', 'code_debug', 'code_explain',
            'code_complete', 'code_complexity', 'code_concept',
            'code_tracing', 'code_convert', 'sql_query',
        ];

        $validated = $request->validate([
            'type' => ['required', Rule::in(array_merge([
                'multiple_choice', 'true_false', 'short_answer', 'essay',
                'fill_blank', 'matching', 'ordering', 'definition',
                'diagram', 'calculation', 'compare', 'case_study', 'code',
            ], $codeSubTypes))],
            'difficulty'       => ['required', Rule::in(['easy', 'medium', 'hard'])],
            'count'            => ['required', 'integer', 'min:1', 'max:50'],
            'force_regenerate' => ['sometimes', 'boolean'],
            'from_page'        => ['sometimes', 'nullable', 'integer', 'min:1'], // ✅ أضفناهم
            'to_page' => ['sometimes', 'nullable', 'integer', 'min:1', 'gte:from_page'],
        ]);

        $rawType    = $validated['type'];
        $type       = in_array($rawType, $codeSubTypes) ? 'code' : $rawType;
        $difficulty = $validated['difficulty'];
        $count      = (int) $validated['count'];

        // ✅ استقبل الـ range بشكل صحيح من الـ request
        // ✅ استقبل الـ range
        $fromPage = $request->input('from_page');
        $toPage   = $request->input('to_page');

        $file = $this->findFileOrFail($id);

        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        // ✅ الحل الصحيح: جرب pages أولاً، وإذا مافيش استخدم extracted_text
        // تحقق من البيانات أولاً
        $sourceData = !empty($file->pages) ? $file->pages : $file->extracted_text;

        if (empty($sourceData)) {
            return response()->json(['success' => false, 'message' => 'No text extracted yet.'], 422);
        }

        // استخرج الصفحات
        $rawText = $this->extractPageRange($sourceData, $fromPage, $toPage);

        if (empty(trim($rawText))) {
            return response()->json(['success' => false, 'message' => 'No extractable text found in this file.'], 422);
        }

        $cleanText = $this->cleanText($rawText);
        if (empty(trim($cleanText))) {
            return response()->json(['success' => false, 'message' => 'Text could not be cleaned for processing.'], 422);
        }

        $lang    = $this->detectLanguage($cleanText);
        $textLen = mb_strlen($cleanText);

        $chunkSize = $this->dynamicChunkSize($textLen, $count);
        $rawChunks = array_values(array_filter(
            $this->chunkText($cleanText, $chunkSize),
            fn($c) => !$this->isUselessChunk($c)
        ));
        $totalChunks = count($rawChunks);

        if ($totalChunks === 0) {
            return response()->json(['success' => false, 'message' => 'No usable text chunks to process.'], 422);
        }

        Log::info("Questions: textLen={$textLen}, count={$count}, chunkSize={$chunkSize}, totalChunks={$totalChunks}");

        $chunkMeta = [];
        foreach ($rawChunks as $i => $chunk) {
            $chunkMeta[$i] = [
                'examples' => $this->countSolvedExamples($chunk),
                'density'  => $this->contentDensity($chunk),
                'len'      => mb_strlen($chunk),
            ];
        }

        $budgets = $this->redistributeBudget($count, $chunkMeta, $totalChunks);

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
        $shortageReason = null;

        while (count($questionsArray) < $count && $round < $maxRounds) {
            $round++;
            $stillNeeded   = $count - count($questionsArray);
            $remainBudgets = $round === 1
                ? $budgets
                : $this->redistributeBudget($stillNeeded, $chunkMeta, $totalChunks);

            foreach ($allChunks as $chunkIndex => $chunk) {
                if (count($questionsArray) >= $count) break;

                $chunkBudget = $remainBudgets[$chunkIndex] ?? 0;
                if ($chunkBudget <= 0) continue;

                $requestedBatch      = min($chunkBudget, self::QUESTIONS_PER_CHUNK_MAX);
                $meta                = $chunkMeta[$chunkIndex];
                $lastRawPartForChunk = null;

                do { $seed = rand(1, 999999); } while (in_array($seed, $usedSeeds));
                $usedSeeds[] = $seed;

                $prompt = $this->prompt('questions', [
                    'text'            => $chunk,
                    'count'           => $requestedBatch,
                    'type'            => $type,
                    'difficulty'      => $difficulty,
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

                Log::info('RAW QA OUTPUT chunk=' . $chunkIndex . ' round=' . $round . ': ' . substr($part, 0, 2000));

                $part = $this->normalizeToMarkdown($part);
                if (!preg_match('/##\s*Question\s*\d+/i', $part)) {
                    Log::warning("Questions chunk {$chunkIndex} round {$round} — no questions found.");
                    continue;
                }

                if ($lastRawPartForChunk !== null) {
                    similar_text($lastRawPartForChunk, $part, $pct);
                    if ($pct > 92) {
                        Log::info("Chunk {$chunkIndex} round {$round} too similar ({$pct}%) — skipped.");
                        continue;
                    }
                }
                $lastRawPartForChunk = $part;

                $part         = trim(preg_replace('/^.*?(##\s*Question\s*\d+)/is', '$1', $part));
                $newQuestions = $this->splitIntoIndividualQuestions($part);

                foreach ($newQuestions as $q) {
                    if (count($questionsArray) >= $count) break;
                    $hash = md5(preg_replace('/\s+/', ' ', strtolower(strip_tags($q))));
                    if (isset($seenHashes[$hash])) continue;
                    $seenHashes[$hash] = true;
                    $questionsArray[]  = $q;
                }
            }
        }

        // ── Completion pass ────────────────────────────────────
        if (count($questionsArray) < $count) {
            $stillNeeded  = $count - count($questionsArray);
            $densities    = array_column($chunkMeta, 'density');
            $richestIdx   = array_keys($densities, max($densities))[0] ?? 0;
            $richestChunk = $allChunks[$richestIdx];
            $meta         = $chunkMeta[$richestIdx];

            do { $seed = rand(1, 999999); } while (in_array($seed, $usedSeeds));
            $batchSize = min($stillNeeded + 1, self::QUESTIONS_PER_CHUNK_MAX);

            Log::info("Completion pass: still need {$stillNeeded}, requesting {$batchSize}.");

            $completionPrompt = $this->prompt('questions', [
                'text'            => $richestChunk,
                'count'           => $batchSize,
                'type'            => $type,
                'difficulty'      => $difficulty,
                'chunk_index'     => 1,
                'total_chunks'    => 1,
                'seed'            => $seed,
                'timestamp'       => $timestamp . '_completion',
                'language'        => $lang,
                'solved_examples' => $meta['examples'],
                'content_type'    => $meta['examples'] > 0 ? 'has_solved_examples' : 'theory_only',
            ]);

            $part = $this->callModelWithRetry($completionPrompt, 'qa', 0.6);
            if ($part !== null) {
                $part         = $this->normalizeToMarkdown($part);
                $part         = trim(preg_replace('/^.*?(##\s*Question\s*\d+)/is', '$1', $part));
                $newQuestions = $this->splitIntoIndividualQuestions($part);
                foreach ($newQuestions as $q) {
                    if (count($questionsArray) >= $count) break;
                    $hash = md5(preg_replace('/\s+/', ' ', strtolower(strip_tags($q))));
                    if (isset($seenHashes[$hash])) continue;
                    $seenHashes[$hash] = true;
                    $questionsArray[]  = $q;
                }
            }
        }

        if (empty($questionsArray)) {
            return response()->json([
                'success' => false,
                'message' => 'Model failed to generate questions after multiple attempts.',
            ], 500);
        }

        $questionsArray = array_slice($questionsArray, 0, $count);
        $questionsArray = array_map(fn($seg) => trim(preg_replace('/##QSEP##/i', '', $seg)), $questionsArray);
        $questionsArray = array_map(function ($seg, $idx) {
            return preg_replace('/##\s*Question\s*\d+/i', '## Question ' . ($idx + 1), $seg, 1);
        }, $questionsArray, array_keys($questionsArray));

        $content     = trim(implode("\n\n##QSEP##\n\n", $questionsArray));
        $actualCount = count($questionsArray);

        if ($actualCount < $count) {
            $shortageReason = "Model could only generate {$actualCount} unique questions from the available content.";
        }

        Question::create([
            'user_id'    => (string) auth()->id(),
            'file_id'    => (string) $file->id,
            'question'   => $content,
            'type'       => $rawType,
            'difficulty' => $difficulty,
            'count'      => $actualCount,
        ]);

        return response()->json([
            'success' => true,
            'data'    => array_filter([
                'questions'       => $content,
                'requested_count' => $count,
                'actual_count'    => $actualCount,
                'shortage_reason' => $shortageReason,
            ]),
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /files/{id}/explain
    // ────────────────────────────────────────────────────────
    public function explain(Request $request, $id)
    {
        set_time_limit(0);

        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        if (empty($file->extracted_text)) {
            return response()->json(['success' => false, 'message' => 'Text not extracted yet.'], 422);
        }

        $cleanText   = $this->cleanText(
            $this->extractPageRange($file->extracted_text, $request->input('page_from'), $request->input('page_to'))
        );
        $lang        = $this->detectLanguage($cleanText);
        $chunkSize   = $this->dynamicChunkSize(mb_strlen($cleanText), 0, 1800);
        $chunks      = $this->chunkText($cleanText, $chunkSize);
        $partials    = [];
        $totalChunks = count($chunks);
        $timestamp   = now()->timestamp;

        foreach ($chunks as $i => $chunk) {
            $chunkNum = $i + 1;
            if ($this->isUselessChunk($chunk)) {
                Log::info("Explain chunk {$chunkNum} identified as useless — skipped.");
                continue;
            }

            // explain الـ chunk مباشرة
            $systemPrompt = $this->prompt('explain', [
                'text'      => $chunk,
                'chunk'     => $chunkNum,
                'total'     => $totalChunks,
                'timestamp' => $timestamp,
                'seed'      => rand(1, 99999),
            ]);
            $userMsg = 'اشرح النص الموجود في الـ TEXT بالعامية المصرية بالتفصيل الكامل. ممنوع تنسخ النص الأصلي. ممنوع أي كلام صيني أو ياباني أو كوري.';
            $part = $this->callModelWithRetry($userMsg, 'explain', 0.5, $systemPrompt, 5);
            if ($part === null) continue;

            // فلتر: لو الـ output إنجليزي خالص من غير عربي → retry
            $arCount = preg_match_all('/[\x{0600}-\x{06FF}]/u', $part);
            $enCount = preg_match_all('/[A-Za-z]/', $part);
            $mathCount = substr_count($part, '$$') / 2;
            $total   = max(1, $arCount + $enCount);
            if (($arCount / $total) < 0.20 && mb_strlen($part) > 200) {
                // إعادة المحاولة بـ prompt أقوى
                $retryMsg = 'اشرح النص الموجود في الـ TEXT بالعامية المصرية فقط. ممنوع تنسخ النص. ممنوع إنجليزي خالص.';
                $retryPart = $this->callModelWithRetry($retryMsg, 'explain', 0.7, $systemPrompt, 5);
                if ($retryPart !== null) $part = $retryPart;
            }

            $header     = $lang === 'arabic'
                ? "## الجزء {$chunkNum} من {$totalChunks}"
                : "## Part {$chunkNum} of {$totalChunks}";
            Log::info("EXPLAIN_RAW_CHUNK_{$chunkNum}:\n" . $part);
        $partials[] = [
                'part'    => $chunkNum,
                'total'   => $totalChunks,
                'header'  => $header,
                'content' => $part,
            ];
        }

        if (empty($partials)) {
            return response()->json(['success' => false, 'message' => 'Model failed to generate explanation.'], 500);
        }

        $content = implode("\n\n", array_map(fn($p) => $p['content'], $partials));

        Explanation::create([
            'user_id' => (string) auth()->id(),
            'file_id' => (string) $file->id,
            'content' => $content,
        ]);

        return response()->json(['success' => true, 'data' => ['explanation' => $partials]]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /files/{id}/chat
    // ────────────────────────────────────────────────────────
    public function chat(Request $request, $id)
    {
        set_time_limit(0);

        $request->validate(['message' => ['required', 'string', 'max:2000']]);

        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        $userMessage = trim($request->input('message'));
        $context     = trim($request->input('summary', '') ?: $request->input('explanation', ''));
        $history     = $request->input('history', []);

        $historyText = '';
        if (!empty($history) && is_array($history)) {
            foreach (array_slice($history, -6) as $turn) {
                $role    = ($turn['role'] ?? 'user') === 'user' ? 'User' : 'Assistant';
                $content = trim($turn['content'] ?? '');
                if ($content) $historyText .= "{$role}: {$content}\n";
            }
        }

        $contextSnippet = mb_substr($this->cleanText($context), 0, 1500);
        $lang           = $this->detectLanguage($userMessage . ' ' . $contextSnippet);
        $promptText     = $this->buildChatPrompt($lang, $contextSnippet, $historyText, $userMessage);
        $reply          = $this->callModelWithRetry($promptText, 'chat', 0.5);

        if ($reply === null) {
            return response()->json(['success' => false, 'message' => 'Model failed to reply.'], 500);
        }

        return response()->json(['success' => true, 'data' => ['reply' => $reply]]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /files/{id}/mindmap
    // ────────────────────────────────────────────────────────
    public function mindmap(Request $request, $id)
    {
        set_time_limit(0);

        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        $inputText = trim($request->input('summary', ''));
        if (empty($inputText)) $inputText = $file->extracted_text ?? '';

        if (empty(trim($inputText))) {
            return response()->json(['success' => false, 'message' => 'No text available to build mind map.'], 422);
        }

        $cleanText  = $this->cleanText($inputText);
        $snippet    = mb_substr($cleanText, 0, 3000);
        $lang       = $this->detectLanguage($cleanText);
        $promptText = $this->buildMindMapPrompt($snippet, $lang);
        $raw        = $this->callModelWithRetry($promptText, 'mindmap', 0.3);

        if ($raw === null) {
            return response()->json(['success' => false, 'message' => 'Model failed to generate mind map.'], 500);
        }

        $tree = $this->parseMindMapJson($raw);
        if ($tree === null) {
            Log::warning('mindmap: could not parse JSON from model response', ['raw' => $raw]);
            return response()->json(['success' => false, 'message' => 'Model returned an invalid mind map structure.'], 500);
        }

        return response()->json(['success' => true, 'data' => $tree]);
    }

    // ────────────────────────────────────────────────────────
    //  GET /files/{id}/results
    // ────────────────────────────────────────────────────────
    public function results($id)
    {
        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        $fileId = (string) $file->id;

        return response()->json([
            'success' => true,
            'data'    => [
                'file'        => $this->formatFile($file),
                'summary'     => Summary::where('file_id', $fileId)->latest()->get()
                    ->map(fn($s) => ['content' => $s->content, 'date' => $s->created_at?->toISOString()])->values(),
                'questions'   => Question::where('file_id', $fileId)->latest()->get()
                    ->map(fn($q) => [
                        'content'    => $q->question,
                        'type'       => $q->type,
                        'difficulty' => $q->difficulty,
                        'count'      => $q->count,
                        'date'       => $q->created_at?->toISOString(),
                    ])->values(),
                'explanation' => Explanation::where('file_id', $fileId)->latest()->get()
                    ->map(fn($e) => ['content' => $e->content, 'date' => $e->created_at?->toISOString()])->values(),
            ],
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  DELETE /files/{id}
    // ────────────────────────────────────────────────────────
    public function destroy($id)
    {
        $file = $this->findFileOrFail($id);
        if (!$file) {
            return response()->json(['success' => false, 'message' => 'File not found or unauthorized'], 404);
        }

        if (!empty($file->file_path)) Storage::disk('public')->delete($file->file_path);

        $fileId = (string) $file->id;
        Summary::where('file_id', $fileId)->delete();
        Question::where('file_id', $fileId)->delete();
        Explanation::where('file_id', $fileId)->delete();
        $file->delete();

        return response()->json(['success' => true, 'message' => 'File deleted successfully']);
    }

    // ════════════════════════════════════════════════════════
    //  PRIVATE HELPERS
    // ════════════════════════════════════════════════════════

    private function findFileOrFail(string $id): ?File
    {
        return File::where('user_id', (string) auth()->id())->where('_id', $id)->first();
    }

    // ────────────────────────────────────────────────────────
    //  extractPageRange
    // ────────────────────────────────────────────────────────
    private function extractPageRange($pagesData, $pageFrom, $pageTo): string
    {
        // 1. إذا كان النص القادم عبارة عن JSON String قم بفك تشفيره
        if (is_string($pagesData)) {
            $decoded = json_decode($pagesData, true);
            if (is_array($decoded)) {
                $pagesData = $decoded;
            }
        }

        // 2. إذا كانت المصفوفة تحتوي على صفحات مهيكلة
        if (is_array($pagesData)) {
            if (empty($pagesData)) return '';

            $from = max(1, (int)($pageFrom ?? 1));
            $to   = min(count($pagesData), (int)($pageTo ?? count($pagesData)));

            if ($from > $to) return '';

            $slicedPages = array_slice($pagesData, $from - 1, $to - $from + 1);
            
            // ✨ التعديل الذكي: استخراج حقل text فقط إذا كانت الصفحة عبارة عن مصفوفة داخلياً
            $textChunks = array_map(function($page) {
                if (is_array($page) && isset($page['text'])) {
                    return $page['text'];
                }
                return is_string($page) ? $page : '';
            }, $slicedPages);
            
            Log::info("extractPageRange: Extracted pages {$from}-{$to} from " . count($pagesData) . " total pages");
            return implode("\n\n", array_filter($textChunks));
        }

        // 3. إذا كانت text عادي (fallback)
        return is_string($pagesData) ? trim($pagesData) : '';
    }
    
    // ────────────────────────────────────────────────────────
    //  dynamicChunkSize
    // ────────────────────────────────────────────────────────
    private function dynamicChunkSize(int $textLen, int $questionCount, int $baseOverride = 0): int
    {
        $base = $baseOverride > 0 ? $baseOverride : self::CHUNK_SIZE_BASE;

        if ($questionCount === 0) {
            $size = $base;
        } else {
            $neededChunks = max(1, (int) ceil($questionCount / self::QUESTIONS_PER_CHUNK_MAX));
            $idealSize    = (int) ceil($textLen / $neededChunks);
            $size         = max((int) ($base * 0.6), min($idealSize, (int) ($base * 1.2)));
        }

        $size = max(self::CHUNK_SIZE_MIN, min($size, self::CHUNK_SIZE_MAX));

        $estimatedChunks = (int) ceil($textLen / $size);
        if ($estimatedChunks > self::MAX_CHUNKS) {
            $size = min((int) ceil($textLen / self::MAX_CHUNKS), self::CHUNK_SIZE_MAX);
        }

        return $size;
    }

    // ────────────────────────────────────────────────────────
    //  callModelWithRetry
    // ────────────────────────────────────────────────────────
    private function callModelWithRetry(
        string  $prompt,
        string  $task,
        float   $temperature,
        ?string $systemOverride = null,
        int     $maxRetries = 2
    ): ?string {
        for ($attempt = 0; $attempt <= $maxRetries; $attempt++) {
            try {
                $payload = [
                    'prompt'      => $prompt,
                    'task'        => $task,
                    'temperature' => $temperature,
                    // ❌ لا max_tokens هنا — السيرفر بيقرر حسب الـ task
                ];

                if ($systemOverride !== null) {
                    $payload['system_override'] = $systemOverride;
                }

                $response = Http::withHeaders(self::NGROK_HEADERS)
                    ->timeout(0)
                    ->post(self::MODEL_URL . '/generate', $payload);

                if (!$response->successful()) {
                    $status = $response->status();
                    Log::warning("Model call failed (attempt {$attempt}): HTTP {$status}");
                    if ($status === 404) return null;
                    if ($attempt < $maxRetries) sleep($status === 503 ? 60 : 2);
                    continue;
                }

                $part = trim($response->json('response') ?? '');
                if (empty($part)) {
                    Log::warning("Model returned empty response (attempt {$attempt}).");
                    if ($attempt < $maxRetries) sleep(2);
                    continue;
                }

                if ($this->isRepetitive($part)) {
                    Log::warning("Model returned repetitive response (attempt {$attempt}) — skipped.");
                    if ($attempt < $maxRetries) sleep(2);
                    continue;
                }
                $part = preg_replace('/[\x{4E00}-\x{9FFF}\x{3040}-\x{30FF}\x{AC00}-\x{D7AF}]+/u', '', $part);
                // FIX: strip Chinese/Japanese/Korean chars then clean spaces
                $part = preg_replace('/[^\S\n]+/', ' ', $part);
                $part = preg_replace('/\n{3,}/', "\n\n", $part);
                // شيل أي سطر بيبدأ بـ "النص:" أو "النص الأصلي:"
                $part = preg_replace('/^(?:النص|النص الأصلي|Original Text|Text)\s*:[^\n]*\n?/mu', '', $part);
                // شيل OCR artifacts
                $part = preg_replace('/[\x{25A0}-\x{25FF}\x{2600}-\x{26FF}]/u', '', $part);
                // حول headings لـ bold بدل heading كبير
                $part = preg_replace('/^#{1,4}\s+(.+)$/mu', '**$1**', $part);

                // Fix broken display math blocks
                $part = preg_replace_callback('/\$\$([^$]*)\$\$/', function($m) {
                    $inner = trim($m[1]);
                    return empty($inner) ? '' : '$$' . $inner . '$$';
                }, $part);

                $part = trim($part);
                return $part;

            } catch (\Exception $e) {
                Log::warning("Model call exception (attempt {$attempt}): " . $e->getMessage());
                if ($attempt < $maxRetries) sleep(pow(2, $attempt + 1));
            }
        }
        return null;
    }

    // ────────────────────────────────────────────────────────
    //  buildChatPrompt
    // ────────────────────────────────────────────────────────
    private function buildChatPrompt(string $language, string $context, string $history, string $userMessage): string
    {
        $langInstruction = match ($language) {
            'arabic'  => 'Reply in Arabic only.',
            'english' => 'Reply in English only.',
            default   => "Reply in the same language as the user's message.",
        };

        $contextBlock = $context
            ? "DOCUMENT CONTEXT (use this to answer):\n{$context}\n\n"
            : '';

        $historyBlock = $history
            ? "CONVERSATION HISTORY:\n{$history}\n"
            : '';

        return <<<PROMPT
You are a helpful AI assistant answering questions about a document.
{$langInstruction}
Use LaTeX for any math: inline \$...\$, block \$\$...\$\$.
Keep answers concise and accurate.

{$contextBlock}{$historyBlock}User: {$userMessage}
Assistant:
PROMPT;
    }

    // ────────────────────────────────────────────────────────
    //  buildMindMapPrompt
    // ────────────────────────────────────────────────────────
    private function buildMindMapPrompt(string $text, string $lang): string
    {
        $langInstruction = match ($lang) {
            'arabic'  => 'All labels must be in Arabic.',
            'english' => 'All labels must be in English.',
            default   => 'Use the dominant language of the text for all labels.',
        };

        return <<<PROMPT
You are a mind-map generator.
{$langInstruction}

Analyze the text below and return a JSON mind map.

RULES:
1. Root node = main topic of the text.
2. Level-1 children = 3 to 6 main ideas/chapters.
3. Level-2 children = 2 to 4 sub-points per main idea.
4. Level-3 children (optional) = 1 to 2 details per sub-point.
5. Labels must be SHORT (2-6 words max).
6. Return ONLY valid JSON. No explanation. No markdown fences.

JSON FORMAT:
{
  "label": "Main Topic",
  "children": [
    {
      "label": "Idea 1",
      "children": [
        { "label": "Sub 1.1", "children": [] },
        { "label": "Sub 1.2", "children": [] }
      ]
    }
  ]
}

TEXT:
{$text}
PROMPT;
    }

    // ────────────────────────────────────────────────────────
    //  parseMindMapJson
    // ────────────────────────────────────────────────────────
    private function parseMindMapJson(string $raw): ?array
    {
        // 1. شيل markdown fences
        $clean = preg_replace('/^```[\w]*\s*/m', '', $raw);
        $clean = preg_replace('/```\s*$/m', '', $clean);
        $clean = trim($clean);

        // 2. استخرج أول JSON object كامل بـ brace matching
        $start = strpos($clean, '{');
        if ($start === false) return null;
        $depth = 0;
        $end   = -1;
        for ($i = $start; $i < strlen($clean); $i++) {
            if ($clean[$i] === '{') $depth++;
            elseif ($clean[$i] === '}') {
                $depth--;
                if ($depth === 0) { $end = $i; break; }
            }
        }
        if ($end === -1) return null;
        $jsonStr = substr($clean, $start, $end - $start + 1);

        // 3. صلح trailing commas
        $jsonStr = preg_replace('/,\s*([}\\]])/', '$1', $jsonStr);

        // 4. حاول parse
        $decoded = json_decode($jsonStr, true);

        // 5. لو فشل جرب تنظيف أكتر
        if (json_last_error() !== JSON_ERROR_NONE) {
            $jsonStr = preg_replace('/[\x00-\x1F\x7F]/u', '', $jsonStr);
            $decoded = json_decode($jsonStr, true);
        }

        if (json_last_error() !== JSON_ERROR_NONE) return null;
        if (!isset($decoded['label'])) return null;

        // 6. normalize nodes
        $this->normalizeNodes($decoded);
        return $decoded;
    }

    private function normalizeNodes(array &$node): void
    {
        if (!isset($node['children']) || !is_array($node['children'])) {
            $node['children'] = [];
        }
        $node['label'] = mb_substr(trim($node['label'] ?? '...'), 0, 50);
        foreach ($node['children'] as &$child) {
            if (is_array($child)) $this->normalizeNodes($child);
        }
    }

    // ────────────────────────────────────────────────────────
    //  isUselessChunk
    // ────────────────────────────────────────────────────────
    private function isUselessChunk(string $chunk): bool
    {
        $trimmed = trim($chunk);
        if (mb_strlen($trimmed) < 50) return true;

        // Code content → always useful
        if (preg_match('/```[\s\S]{10,}```/u', $trimmed)) return false;
        if (substr_count($trimmed, '`') >= 4) return false;

        // Math-heavy → always useful
        // FIX: كان 20 — رفعناه لـ 15 وأضفنا LaTeX commands
        preg_match_all('/[\$\=\+\-\*\/\^\{\}\(\)\[\]]/', $trimmed, $mathMatches);
        if (count($mathMatches[0]) > 15) return false;
        if (preg_match('/\\\\(?:frac|int|sum|partial|sqrt|lim|infty|alpha|beta|theta|lambda|sigma)\b/', $trimmed)) return false;

        // Mostly page numbers / index lines
        $lines        = preg_split('/\n/', $trimmed);
        $numericLines = array_filter($lines, fn($l) => preg_match('/^\s*[\d\.]+\s*$/', trim($l)));
        if (count($lines) > 5 && count($numericLines) / count($lines) > 0.5) return true;

        // Standard useless headers
        $uselessHeaders = [
            'bibliography', 'references', 'index', 'table of contents',
            'contents', 'acknowledgements', 'acknowledgments', 'appendix',
            'المراجع', 'قائمة المراجع', 'الفهرس', 'المحتويات', 'الملاحق',
        ];
        $firstLine = mb_strtolower(mb_substr($trimmed, 0, 80));
        foreach ($uselessHeaders as $header) {
            if (str_contains($firstLine, $header)) return true;
        }

        // Code keywords → useful
        $codeKeywords = ['function', 'class', 'return', 'import', 'def ', 'void ', 'int ', 'if ', 'for ', 'while '];
        foreach ($lines as $line) {
            $lower = strtolower(trim($line));
            foreach ($codeKeywords as $kw) {
                if (str_starts_with($lower, $kw)) return false;
            }
        }

        // Mostly short nav lines
        $shortLines = array_filter($lines, fn($l) => str_word_count(trim($l)) <= 3 && trim($l) !== '');
        if (count($lines) > 10 && count($shortLines) / count($lines) > 0.7) return true;

        return false;
    }

    // ────────────────────────────────────────────────────────
    //  detectLanguage
    // ────────────────────────────────────────────────────────
    private function detectLanguage(string $text): string
    {
        $sample = mb_substr($text, 0, 2000);
        preg_match_all('/[\x{0600}-\x{06FF}\x{0750}-\x{077F}]/u', $sample, $arMatches);
        preg_match_all('/[A-Za-z]/', $sample, $enMatches);
        $total   = max(1, count($arMatches[0]) + count($enMatches[0]));
        $arRatio = count($arMatches[0]) / $total;
        if ($arRatio >= 0.75) return 'arabic';
        if ($arRatio <= 0.25) return 'english';
        return 'mixed';
    }

    // ────────────────────────────────────────────────────────
    //  countSolvedExamples
    // ────────────────────────────────────────────────────────
    private function countSolvedExamples(string $chunk): int
    {
        $pattern = '/\b(Example|Solution|Proof|Theorem|Derivation|Exercise|مثال|حل\s|برهان|نظرية|تمرين\s+محلول|تطبيق)\b/ui';
        preg_match_all($pattern, $chunk, $textMatches);
        $codeBlocks       = substr_count($chunk, '```');
        $codeExamples     = (int) floor($codeBlocks / 2);
        preg_match_all('/\b(function|def |class |public |private |static )\b/i', $chunk, $codeMatches);
        $codeKeywordScore = (int) floor(count($codeMatches[0]) / 3);
        return (int) floor(count($textMatches[0]) / 2) + $codeExamples + $codeKeywordScore;
    }

    // ────────────────────────────────────────────────────────
    //  contentDensity
    // ────────────────────────────────────────────────────────
    private function contentDensity(string $chunk): float
    {
        $len          = mb_strlen($chunk);
        $exampleBonus = $this->countSolvedExamples($chunk) * 500;
        preg_match_all('/[\$\=\+\-\*\/\^\{\}\(\)\[\]]/', $chunk, $mathMatches);
        $mathScore = min(count($mathMatches[0]) * 2, 1000);
        $codeScore = min(substr_count($chunk, '```') * 300, 1200);
        preg_match_all('/\\\(?:int|frac|partial|sum|prod|lim|infty|nabla|Delta|sqrt)\b/', $chunk, $calcMatches);
        $calcScore = min(count($calcMatches[0]) * 50, 800);
        return max(1.0, ($len + $exampleBonus + $mathScore + $codeScore + $calcScore) / 1000.0);
    }

    // ────────────────────────────────────────────────────────
    //  redistributeBudget
    // ────────────────────────────────────────────────────────
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

    // ────────────────────────────────────────────────────────
    //  isRepetitive
    // ────────────────────────────────────────────────────────
    private function isRepetitive(string $text): bool
    {
        return (bool) preg_match('/(\b\w+\b)(\s+\1){10,}/i', $text);
    }

    // ────────────────────────────────────────────────────────
    //  splitIntoIndividualQuestions
    // ────────────────────────────────────────────────────────
    private function splitIntoIndividualQuestions(string $blob): array
    {
        $parts = preg_split('/\n?\s*#{0,2}QSEP##\s*\n?/i', $blob);
        $parts = array_values(array_filter(array_map('trim', $parts)));

        $valid = array_values(array_filter(
            $parts,
            fn($seg) => (bool) preg_match('/##\s*Question\s*\d+/i', $seg)
        ));

        if (empty($valid)) {
            $raw   = preg_split('/(?=##\s*Question\s*\d+)/i', $blob);
            $valid = array_values(array_filter(
                array_map('trim', $raw),
                fn($seg) => (bool) preg_match('/##\s*Question\s*\d+/i', $seg)
            ));
        }

        $valid = array_map(fn($seg) => trim(preg_replace('/#{0,2}QSEP##/i', '', $seg)), $valid);

        // filter out invalid questions
        $valid = array_values(array_filter($valid, function ($seg) {
            if (preg_match('/\b(Verify|Check)\b.*\b(No|False|incorrect|wrong|does not|doesn\'t|not satisfied)\b/i', $seg)) return false;
            if (preg_match('/\b(not|does not|doesn\'t)\s+(satisfy|work|hold)\b/i', $seg)) return false;
            return true;
        }));

        // filter empty bodies
        $valid = array_values(array_filter($valid, function ($seg) {
            $body = preg_replace('/##\s*Question\s*\d+[^\n]*\n?/i', '', $seg, 1);
            return trim($body) !== '';
        }));

        return $valid;
    }

    // ────────────────────────────────────────────────────────
    //  cleanText
    //  FIX: منطق $ spacing كان بيكسر LaTeX — استبدلناه
    // ────────────────────────────────────────────────────────
    private function cleanText(string $text): string
    {
        // Remove non-printable except Arabic, Latin, newlines
        $text = preg_replace(
            '/[^\x{0020}-\x{007E}\x{00A0}-\x{024F}\x{0600}-\x{06FF}\x{0750}-\x{077F}\n\r\t]/u',
            ' ', $text
        );
        $text = strip_tags($text);

        // Collapse multiple spaces (not newlines)
        $text = preg_replace('/[^\S\n]+/', ' ', $text);

        // ── Merge orphaned inline-math lines ──────────────────────
        // PDF extractors put lone vars (x, T, k, t) on their own lines.
        // Stitch them back — run twice to catch consecutive orphans.
        for ($pass = 0; $pass < 2; $pass++) {
            // pattern: text_line \n lone_var \n next_line → one line
            $text = preg_replace(
                '/([^\n]+)\n([a-zA-Z_][a-zA-Z_\d]{0,3}|,)\n([^\n]+)/u',
                '$1 $2 $3',
                $text
            );
            // lone var followed by punctuation on its own line
            $text = preg_replace(
                '/([^\n]+)\n([a-zA-Z_][a-zA-Z_\d]{0,3})([.,;:])\n/u',
                '$1 $2$3' . "\n",
                $text
            );
        }

        // Remove lone heading markers
        $text = preg_replace('/^#{1,6}\s*$/m', '', $text);

        // Collapse 3+ newlines → 2
        $text = preg_replace('/\n{3,}/', "\n\n", $text);

        // Remove orphan page numbers
        $text = preg_replace('/\b(Page|صفحة|ص)\s*\d+\b/iu', '', $text);
        // Remove image references from PDF extraction
        $text = preg_replace('/!\[\]\([^)]*\.(jpeg|jpg|png|gif|webp)[^)]*\)/i', '', $text);
        // Remove table of contents lines (number | text | number)
        $text = preg_replace('/^[\d\.]+\s*\|[^\n]+\|\s*[\d]+\s*\|?\s*$/mu', '', $text);

        // Remove control characters
        $text = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $text);

        // Add space after punctuation if missing (not inside LaTeX)
        $text = preg_replace('/([.,;:!?])(?=[^\s\n\$])/', '$1 ', $text);

        // Ensure spaces around $$ (display math)
        $text = preg_replace('/(?<=[^\s\n])\$\$/', ' $$', $text);
        $text = preg_replace('/\$\$(?=[^\s\n])/', '$$ ', $text);

        return trim($text);
    }

    // ────────────────────────────────────────────────────────
    //  fixReversedArabic — REMOVED
    //  كان بيعكس ترتيب الكلمات في كل سطر فيه عربي حتى لو مش محتاج
    //  PDF marker-pdf الحديث بيطلع النص صح — مش محتاج manual reversal
    // ────────────────────────────────────────────────────────

    // ────────────────────────────────────────────────────────
    //  chunkText
    // ────────────────────────────────────────────────────────
    private function chunkText(string $text, int $maxChars): array
    {
        $TARGET    = $maxChars;
        $MIN_CHUNK = (int) ($maxChars * 0.4);
        $MAX_CHUNK = (int) ($maxChars * 1.2);
        $chunks    = [];
        $text      = trim($text);

        while (mb_strlen($text) > $TARGET) {
            $splitAt = false;
            $window  = mb_substr($text, $MIN_CHUNK, $TARGET - $MIN_CHUNK);

            // 1. Markdown heading
            if (preg_match('/\n(?=#{1,6}\s)/u', $window, $m, PREG_OFFSET_CAPTURE)) {
                $splitAt = $MIN_CHUNK + $m[0][1];
            }

            // 2. Example / Solution start
            if ($splitAt === false && preg_match(
                '/\n(?=(Example|Solution|Proof|Theorem|مثال|حل|برهان|نظرية|تمرين)\b)/u',
                $window, $m, PREG_OFFSET_CAPTURE
            )) {
                $splitAt = $MIN_CHUNK + $m[0][1];
            }

            // 3. Double newline
            if ($splitAt === false) {
                $pos = mb_strrpos(mb_substr($text, 0, $TARGET), "\n\n");
                if ($pos !== false && $pos >= $MIN_CHUNK) $splitAt = $pos;
            }

            // 4. Single newline
            if ($splitAt === false) {
                $pos = mb_strrpos(mb_substr($text, 0, $TARGET), "\n");
                if ($pos !== false && $pos >= $MIN_CHUNK) $splitAt = $pos;
            }

            // 5. Sentence end
            if ($splitAt === false) {
                $w = mb_substr($text, 0, $TARGET);
                foreach (['. ', '؟ ', '! ', ".\n", "؟\n", "!\n"] as $delim) {
                    $pos = mb_strrpos($w, $delim);
                    if ($pos !== false && $pos >= $MIN_CHUNK) {
                        $splitAt = $pos + mb_strlen($delim) - 1;
                        break;
                    }
                }
            }

            // 6. Space
            if ($splitAt === false) {
                $pos = mb_strrpos(mb_substr($text, 0, $TARGET), ' ');
                if ($pos !== false && $pos >= $MIN_CHUNK) $splitAt = $pos;
            }

            // 7. Hard cut
            if ($splitAt === false || $splitAt > $MAX_CHUNK) $splitAt = $MAX_CHUNK;

            $chunk = trim(mb_substr($text, 0, $splitAt));
            if ($chunk !== '') $chunks[] = $chunk;
            $text = trim(mb_substr($text, $splitAt));
        }

        if ($text !== '') $chunks[] = $text;
        return $chunks;
    }

    // ────────────────────────────────────────────────────────
    //  normalizeToMarkdown
    //  FIX: كانت فيها syntax error بسبب تكرار الكود وـ } زيادة
    // ────────────────────────────────────────────────────────
    private function normalizeToMarkdown(string $raw): string
    {
        // Strip markdown code fences wrapping the whole output
        $clean = preg_replace('/^```[\w]*\s*/m', '', $raw);
        $clean = preg_replace('/```\s*$/m', '', $clean);
        $clean = trim($clean);

        // Try JSON array format first
        $decoded = json_decode($clean, true);
        if (json_last_error() === JSON_ERROR_NONE && is_array($decoded)) {
            $md = $this->jsonToMarkdown($decoded);
            if (!empty($md)) return $md;
        }

        // Normalize ### Question N → ## Question N
        $clean = preg_replace('/^###\s*Question\s*(\d+)/mi', '## Question $1', $clean);
        // Normalize **Question N** → ## Question N
        $clean = preg_replace('/^\*{1,2}Question\s*(\d+)\*{0,2}/mi', '## Question $1', $clean);
        // Normalize **Question N:** → ## Question N
        $clean = preg_replace('/^\*{1,2}Question\s*(\d+)[:\.]?\*{0,2}/mi', '## Question $1', $clean);

        // Remove metadata lines
        $clean = preg_replace('/^###\s*(Type|Difficulty|Topic|Question):[^\n]*/mi', '', $clean);

        // Normalize bare ## or ##--- → ##QSEP##
        $clean = preg_replace('/^##\s*-{3,}\s*$/mi', '##QSEP##', $clean);
        $clean = preg_replace('/^##\s*$/mi', '##QSEP##', $clean);

        // Normalize --- → ##QSEP##
        $clean = preg_replace('/^-{3,}\s*$/mi', '##QSEP##', $clean);

        // Add ##QSEP## after **Answer:** before next ## Question
        $clean = preg_replace(
            '/(\*\*Answer:\*\*[^\n]*)(\n)(?!\s*##QSEP##)(?=\s*##\s*Question)/i',
            "$1\n##QSEP##\n",
            $clean
        );

        // Add ##QSEP## after closing code block before next ## Question
        $clean = preg_replace(
            '/(```\s*)(\n)(?!\s*##QSEP##)(?=\s*##\s*Question)/i',
            "$1\n##QSEP##\n",
            $clean
        );

        // Ensure ends with ##QSEP##
        if (trim($clean) !== '' && !preg_match('/#{0,2}QSEP##\s*$/i', trim($clean))) {
            $clean = rtrim($clean) . "\n##QSEP##";
        }

        // Clean multiple blank lines
        $clean = preg_replace('/\n{3,}/', "\n\n", $clean);

        return trim($clean);
    }

    // ────────────────────────────────────────────────────────
    //  jsonToMarkdown
    // ────────────────────────────────────────────────────────
    private function jsonToMarkdown(array $decoded): string
    {
        $questions = isset($decoded[0]) ? $decoded
            : (isset($decoded['questions']) && is_array($decoded['questions'])
                ? $decoded['questions'] : null);
        if (!$questions) return '';

        $markdown = '';
        $counter  = 1;
        foreach ($questions as $q) {
            if (!is_array($q)) continue;
            $qText   = $q['question'] ?? $q['q'] ?? '';
            $aText   = $q['answer']   ?? $q['a'] ?? '';
            $options = $q['options']  ?? $q['choices'] ?? [];
            if (empty($qText)) continue;

            $markdown .= "## Question {$counter}\n\n{$qText}\n\n";

            if (!empty($options) && is_array($options)) {
                $letters = ['A', 'B', 'C', 'D', 'E'];
                foreach ($options as $idx => $opt) {
                    $letter  = $letters[$idx] ?? ($idx + 1);
                    $optText = is_array($opt) ? ($opt['text'] ?? json_encode($opt)) : $opt;
                    $markdown .= "{$letter}) {$optText}\n";
                }
                $markdown .= "\n";
            }

            if (!empty($aText)) $markdown .= "**Answer:** {$aText}\n";
            $markdown .= "##QSEP##\n\n";
            $counter++;
        }

        return trim($markdown);
    }

    // ────────────────────────────────────────────────────────
    //  formatFile
    //  FIX: أضفنا text_length للـ Flutter يعرف حجم النص
    // ────────────────────────────────────────────────────────
    private function formatFile($file)
    {
        return [
            'id' => $file->id,
            'fileName' => $file->file_name,
            'size' => $file->size,
            'status' => $file->status,
            'has_text' => !empty($file->extracted_text),  // ✓ أضف دائماً
            'page_count' => (int) ($file->page_count ?? 0), // ✅ أضف دي
            'createdAt' => $file->created_at,
        ];
    }

    private function countPagesFromText(?string $text): int
    {
        if (empty($text)) return 0;

        preg_match_all('/_page_(\d+)_/i', $text, $matches);
        if (!empty($matches[1])) {
            return (int) max($matches[1]) + 1;
        }

        $dashPages = substr_count($text, "\n---\n") + substr_count($text, "\n-----\n");
        if ($dashPages > 0) return $dashPages + 1;

        $ffPages = substr_count($text, "\f");
        if ($ffPages > 0) return $ffPages + 1;

        return max((int) ceil(mb_strlen($text) / 2000), 1);
    }

    // ────────────────────────────────────────────────────────
    //  formatBytes
    // ────────────────────────────────────────────────────────
    private function formatBytes(int $bytes, int $precision = 2): string
    {
        $units = ['B', 'KB', 'MB', 'GB'];
        $bytes = max($bytes, 0);
        $pow   = $bytes > 0 ? (int) floor(log($bytes) / log(1024)) : 0;
        $pow   = min($pow, count($units) - 1);
        $bytes /= pow(1024, $pow);
        return round($bytes, $precision) . ' ' . $units[$pow];
    }

    // ────────────────────────────────────────────────────────
    //  prompt
    //  FIX: graceful fallback لو ملف الـ prompt مش موجود
    // ────────────────────────────────────────────────────────
    private function prompt(string $name, array $data = []): string
    {
        $path = base_path("prompts/{$name}.md");

        if (!file_exists($path)) {
            Log::error("Prompt template not found: prompts/{$name}.md");
            // Fallback: build a minimal prompt from data
            $text = $data['text'] ?? '';
            return "Process the following text and generate {$name} output:\n\n{$text}";
        }

        $content = file_get_contents($path);

        if ($name === 'questions' && isset($data['type'])) {
            $data['few_shot_example']  = $this->getFewShotExample($data['type']);
            $data['type_instructions'] = $this->getTypeInstructions($data['type']);
        }

        foreach ($data as $key => $value) {
            $content = str_replace('{{' . $key . '}}', (string) $value, $content);
        }

        // Remove unfilled placeholders
        $content = preg_replace('/\{\{[a-z_]+\}\}/', '', $content);

        return $content;
    }

    // ────────────────────────────────────────────────────────
    //  getFewShotExample
    // ────────────────────────────────────────────────────────
    private function getFewShotExample(string $type): string
    {
        $examples = [

            'multiple_choice' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
The Fredholm integral equation of the second kind has the form:

A) $\phi(x) = f(x) + \lambda \int_a^b K(x,t)\phi(t)\,dt$
B) $\phi(x) = \lambda \int_0^x K(x,t)\phi(t)\,dt$
C) $f(x) = \int_a^b K(x,t)\,dt$
D) $\phi(x) = f(x) - \lambda K(x,t)$

**Answer:** A) The second kind includes $\phi(x)$ on both sides; $a,b$ are fixed constants distinguishing it from Volterra.
##QSEP##
EX,

            'true_false' => <<<'EX'
CRITICAL RULE: EVERY question is a STATEMENT — never a question.
No "What", "Which", "How", "Why", "Does", "Is it true that".

EXAMPLE (copy this format exactly):

## Question 1
In Fredholm integral equations of the second kind, the limits of integration $a$ and $b$ are fixed constants.

**Answer:** True. Fixed limits $a,b$ distinguish Fredholm from Volterra equations, where the upper limit is variable $x$.
##QSEP##

## Question 2
The resolvent kernel $R(x,t;\lambda) = \sum_{i=0}^{\infty} \lambda^i k_i(x,t)$ converges for all values of $\lambda$.

**Answer:** False. The series converges only when $|\lambda| < 1$; outside this radius the Neumann series diverges.
##QSEP##
EX,

            'short_answer' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
What distinguishes a Volterra integral equation from a Fredholm integral equation?

**Answer:** In Volterra equations the upper limit of integration is the variable $x$, giving $\int_0^x K(x,t)\phi(t)\,dt$, so the domain grows with $x$. In Fredholm equations both limits $a,b$ are fixed constants. This makes Volterra equations equivalent to initial-value problems, while Fredholm equations correspond to boundary-value problems.
##QSEP##
EX,

            'essay' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
Derive the Neumann series solution for the Fredholm integral equation $\phi(x) = f(x) + \lambda \int_a^b K(x,t)\phi(t)\,dt$ and state the condition for convergence.

**Answer:** A complete answer must cover:
- Successive substitution: $\phi_0 = f(x)$, $\phi_{n+1} = f(x) + \lambda \int_a^b K(x,t)\phi_n(t)\,dt$
- Iterated kernels: $k_0(x,t)=K(x,t)$, $k_{n+1}(x,t)=\int_a^b K(x,s)k_n(s,t)\,ds$
- Series form: $\phi(x) = f(x) + \lambda \int_a^b R(x,t;\lambda)f(t)\,dt$
- Resolvent kernel: $R(x,t;\lambda) = \sum_{i=0}^{\infty} \lambda^i k_i(x,t)$
- Convergence condition: $|\lambda| < 1$
##QSEP##
EX,

            'fill_blank' => <<<'EX'
CRITICAL: ONE sentence per question. No paragraphs. No context blocks.

## Question 1
The upper limit of integration in a Volterra integral equation is the variable ______.

**Answer:** $x$
##QSEP##

## Question 2
When $r(x) = 0$, the integral equation is classified as a(n) ______ integral equation.

**Answer:** homogeneous
##QSEP##
EX,

            'matching' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
Match each equation type in List A with its correct description in List B.

**List A:**
1. Fredholm equation of the first kind
2. Fredholm equation of the second kind
3. Volterra equation of the second kind
4. Homogeneous Fredholm equation

**List B:**
B1. $\phi(x) = f(x) + \lambda \int_0^x K(x,t)\phi(t)\,dt$
B2. $f(x) = \int_a^b K(x,t)\phi(t)\,dt$
B3. $\phi(x) = \lambda \int_a^b K(x,t)\phi(t)\,dt$
B4. $\phi(x) = f(x) + \lambda \int_a^b K(x,t)\phi(t)\,dt$

**Answer:** 1→B2, 2→B4, 3→B1, 4→B3
##QSEP##
EX,

            'ordering' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
Arrange the following steps for solving a Fredholm equation using the Neumann series in the correct order:

1. Compute the resolvent kernel $R(x,t;\lambda) = \sum \lambda^i k_i(x,t)$
2. Verify convergence: $|\lambda| < 1$
3. Define $k_0(x,t) = K(x,t)$
4. Write the solution $\phi(x) = f(x) + \lambda \int_a^b R(x,t;\lambda)f(t)\,dt$
5. Compute iterated kernels $k_{n+1}(x,t) = \int_a^b K(x,s)k_n(s,t)\,ds$

**Answer:** Correct sequence: 3 → 5 → 1 → 2 → 4
##QSEP##
EX,

            'definition' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
Define the resolvent kernel as used in the Neumann series method.

**Answer:** The resolvent kernel $R(x,t;\lambda) = \sum_{i=0}^{\infty} \lambda^i k_i(x,t)$ is the kernel that converts the integral equation into the explicit solution $\phi(x) = f(x) + \lambda \int_a^b R(x,t;\lambda)f(t)\,dt$. For example, if $K(x,t)=1$ on $[0,1]$, then $R = \frac{1}{1-\lambda}$ for $|\lambda|<1$.
##QSEP##
EX,

            'diagram' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
Sketch a diagram that classifies integral equations by type and kind, showing the relationship between Fredholm, Volterra, first kind, and second kind.

**Answer:** Required elements:
- Root node: "Integral Equations"
- Branch 1: Fredholm → First kind / Second kind
- Branch 2: Volterra → First kind / Second kind (upper limit = $x$)
- Label fixed limits $[a,b]$ on Fredholm branches
- Label variable upper limit $x$ on Volterra branches
##QSEP##
EX,

            'calculation' => <<<'EX'
CRITICAL: Write ALL steps — never skip. Never say "similarly". If 15 steps needed, write 15 steps.

EXAMPLE (copy this format exactly):

## Question 1
Solve $\phi(x) = x + \int_0^x (x-t)\phi(t)\,dt$ using successive approximations. Find $\phi_0$, $\phi_1$, $\phi_2$.

**Answer:**
**Step 1 — Initial approximation:**
$$\phi_0(x) = x$$

**Step 2 — First approximation setup:**
$$\phi_1(x) = x + \int_0^x (x-t)\cdot t\,dt$$

**Step 3 — Evaluate integral:**
$$\int_0^x (x-t)t\,dt = \int_0^x (xt - t^2)\,dt = \frac{x^3}{2} - \frac{x^3}{3} = \frac{x^3}{6}$$

**Step 4 — First approximation result:**
$$\phi_1(x) = x + \frac{x^3}{6}$$

**Step 5 — Second approximation setup:**
$$\phi_2(x) = x + \int_0^x (x-t)\left(t + \frac{t^3}{6}\right)dt$$

**Step 6 — Expand integrand:**
$$= x + \int_0^x \left(xt - t^2 + \frac{xt^3}{6} - \frac{t^4}{6}\right)dt$$

**Step 7 — Integrate term by term:**
$$= x + \frac{x^3}{6} + \frac{x^5}{120}$$

**Step 8 — Final Answer:**
$$\phi(x) \approx \sinh(x) = x + \frac{x^3}{6} + \frac{x^5}{120} + \cdots$$
##QSEP##
EX,

            'compare' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
Compare the Neumann series method and the method of successive approximations for solving Fredholm integral equations.

**Answer:**
**Similarities:**
- Both produce a series solution $\phi = \sum_{n=0}^{\infty} \lambda^n \phi_n$
- Both require $|\lambda|$ small enough for convergence

**Differences:**
- Neumann series works with iterated kernels $k_n(x,t)$; successive approximations iterate on $\phi_n(x)$
- Neumann series gives explicit resolvent kernel; successive approximations give function iterates

**Conclusion:** Neumann series is preferred for theoretical analysis; successive approximations for numerical computation.
##QSEP##
EX,

            'case_study' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
A heat conduction problem leads to $\phi(x) = 1 + \frac{1}{2}\int_0^1 xt\,\phi(t)\,dt$. Find the exact solution using the Neumann series.

**Answer:**
**Step 1 — Identify:** $f(x)=1$, $K(x,t)=xt$, $\lambda=\frac{1}{2}$, interval $[0,1]$.

**Step 2 — Zeroth iterated kernel:**
$$k_0(x,t) = xt$$

**Step 3 — First iterated kernel:**
$$k_1(x,t) = \int_0^1 xs \cdot st\,ds = xt\int_0^1 s^2\,ds = \frac{xt}{3}$$

**Step 4 — Pattern:** $k_n(x,t) = \frac{xt}{3^n}$

**Step 5 — Resolvent kernel:**
$$R(x,t;\tfrac{1}{2}) = xt\sum_{n=0}^{\infty}\left(\tfrac{1}{6}\right)^n = \frac{6xt}{5}$$

**Step 6 — Solution:**
$$\phi(x) = 1 + \frac{1}{2}\int_0^1 \frac{6xt}{5}\,dt = 1 + \frac{3x}{10}$$

**Final Answer:** $\phi(x) = 1 + \frac{3x}{10}$
##QSEP##
EX,

            'code' => <<<'EX'
EXAMPLE (copy this format exactly):

## Question 1
What is the output of the following Python code?

```python
def trapezoidal(f, a, b, n):
    h = (b - a) / n
    result = f(a) + f(b)
    for i in range(1, n):
        result += 2 * f(a + i * h)
    return result * h / 2

print(trapezoidal(lambda x: x**2, 0, 1, 4))
```

**Answer:** Output is `0.328125`.
- $h=0.25$, nodes: $0, 0.25, 0.5, 0.75, 1.0$
- $f$ values: $0,\ 0.0625,\ 0.25,\ 0.5625,\ 1$
- Result $= \frac{0.25}{2}(0 + 2(0.0625+0.25+0.5625) + 1) = 0.328125$
##QSEP##
EX,
        ];

        return $examples[$type]
            ?? "EXAMPLE OUTPUT:\n\n## Question 1\n[statement or question from source text]\n\n**Answer:** [answer]\n##QSEP##";
    }

    // ────────────────────────────────────────────────────────
    //  getTypeInstructions
    // ────────────────────────────────────────────────────────
    private function getTypeInstructions(string $type): string
    {
        $instructions = [

            'multiple_choice' => <<<'INST'
TYPE RULES — multiple_choice:
- One clear question from the source text
- Exactly 4 options: A) B) C) D)
- Only ONE correct answer — others must be plausible but wrong
- Use LaTeX for all math
- Answer: correct letter + one-line justification
INST,

            'true_false' => <<<'INST'
TYPE RULES — true_false:
⚠️  EVERY question MUST be a STATEMENT — NEVER a question.
❌  FORBIDDEN openers: What, Which, How, Why, Does, Is, Are, Can
✅  Write a declarative sentence that is either true or false.
⚠️  ANSWER FORMAT IS STRICT:
**Answer:** True. [one-sentence justification with LaTeX]
OR
**Answer:** False. [one-sentence justification with LaTeX]
❌  FORBIDDEN: answer on same line as statement
❌  FORBIDDEN: omitting the word True or False
- Use LaTeX for all formulas
- Statement must be directly from source text
INST,

            'short_answer' => <<<'INST'
TYPE RULES — short_answer:
- One focused question requiring 2-4 sentence answer
- Answer must use LaTeX for math
- No yes/no questions — require explanation
INST,

            'essay' => <<<'INST'
TYPE RULES — essay:
- One deep derivation or analysis question
- Answer: bullet list of ALL key points with expected LaTeX expressions
INST,

            'fill_blank' => <<<'INST'
TYPE RULES — fill_blank:
⚠️  ONE sentence ONLY. No paragraphs, no context, no introductions.
❌  WRONG: "Integral equations are related to DEs. If y satisfies... then ______."
✅  CORRECT: "The kernel K(x,t) is called degenerate if it equals ______."
✅  CORRECT: "When r(x) = 0, the equation is classified as a(n) ______ integral equation."
- EXACTLY one sentence with exactly one ______
- Blank replaces ONE key term or short formula from source text
- Answer: ONLY the missing item, in LaTeX if math
INST,

            'matching' => <<<'INST'
TYPE RULES — matching:
- List A: exactly 4-5 items (terms or equations)
- List B: exactly 4-5 descriptions, shuffled
- Answer: A number → B number/letter for each pair
INST,

            'ordering' => <<<'INST'
TYPE RULES — ordering:
- List exactly 4-6 steps in SCRAMBLED order
- Steps from an actual procedure in the source text
- Answer: "Correct sequence: X → Y → Z → ..."
INST,

            'definition' => <<<'INST'
TYPE RULES — definition:
- Ask for definition of ONE specific term from source text
- Answer: formal definition + one concrete example with LaTeX
INST,

            'diagram' => <<<'INST'
TYPE RULES — diagram:
⚠️  Question body = ONE sentence only (max 15 words). No bullet points in the question.
❌  WRONG question: writing a list of items to include in the question body
✅  CORRECT: "Draw a tree diagram classifying Fredholm and Volterra integral equations."
✅  CORRECT: "Sketch the relationship between IVP, BVP, and integral equations."
- Model is text-only: answer lists what the diagram must contain
- Answer: bulleted checklist of every required node, label, arrow, and relationship
INST,

            'calculation' => <<<'INST'
TYPE RULES — calculation:
⚠️  NEVER skip steps. NEVER say "similarly" or "by analogy".
⚠️  Write EVERY step even if 15+ steps. Incomplete solutions are WRONG.

Required format:
**Step N — [label]:** explanation
$$LaTeX equation$$

LaTeX rules (strictly enforced):
- Fractions: \frac{a}{b} — NEVER a/b
- Integrals: \int_{a}^{b} f(x)\,dx
- Partial derivatives: \frac{\partial u}{\partial t} — NEVER u_t
- Final answer always in display math: $$result$$
INST,

            'compare' => <<<'INST'
TYPE RULES — compare:
- Compare exactly TWO things from source text
- Required headers: **Similarities:** / **Differences:** / **Conclusion:**
INST,

            'case_study' => <<<'INST'
TYPE RULES — case_study:
- Realistic problem scenario using specific equation from source
- Full step-by-step solution — same rules as calculation type
- Never skip steps
INST,

            'code' => <<<'INST'
TYPE RULES — code:
- Base on actual code or algorithm from source text
- Types: trace output, find bug, complete function, time complexity, explain
- Code always in fenced block with language tag
- Answer: correct output OR fixed code OR complexity with justification
INST,
        ];

        return $instructions[$type]
            ?? "TYPE RULES: Generate {$type} questions directly from source text with clear answers.";
    }
}

