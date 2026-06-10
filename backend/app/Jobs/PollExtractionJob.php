<?php

namespace App\Jobs;

use App\Models\File;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PollExtractionJob implements ShouldQueue
{
    use Queueable;

    public int $tries = 20;
    public int $backoff = 10;

    public function __construct(
        public string $fileId,
        public string $jobId
    ) {}

    public function handle(): void
    {
        $file = File::find($this->fileId);
        if (!$file) return;

        $response = Http::withHeaders([
            'ngrok-skip-browser-warning' => 'true',
            'Accept'                     => 'application/json',
        ])->timeout(30)->get(env('MARKER_URL') . '/status/' . $this->jobId);

        if (!$response->successful()) {
            Log::warning("PollExtractionJob: HTTP {$response->status()} for job {$this->jobId}");
            return;
        }

        $data   = $response->json();
        $status = $data['status'] ?? '';

        if (!empty($data['full_text'])) {
            $file->update([
                'pages'          => $data['pages'] ?? [],
                'extracted_text' => $data['full_text'],
                'page_count'     => $data['page_count'] ?? $data['pages'] ?? null,
                'status'         => 'Ready',
            ]);
            Log::info("PollExtractionJob: file {$this->fileId} ready.");
        } elseif ($status === 'pending' || $status === 'processing') {
            Log::info("PollExtractionJob: still processing, retrying in 10s.");
            self::dispatch($this->fileId, $this->jobId)->delay(now()->addSeconds(10));
        } else {
            $file->update(['status' => 'ExtractionFailed']);
            Log::error("PollExtractionJob: failed for file {$this->fileId}. Response: " . json_encode($data));
        }
    }
}
