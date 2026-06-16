<?php

namespace App\Http\Controllers;

use App\Models\ExamSheet;
use Illuminate\Http\Request;
use Illuminate\Database\Eloquent\ModelNotFoundException;

class ExamSheetController extends Controller
{
    // GET /api/exams
    public function index(Request $request)
    {
        $sheets = ExamSheet::where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'data'    => $sheets,
        ]);
    }

    // GET /api/exams/{id}
    public function show(Request $request, $id)
    {
        $sheet = ExamSheet::where('_id', $id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (!$sheet) {
            return response()->json([
                'success' => false,
                'message' => 'Exam not found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data'    => $sheet,
        ]);
    }

    // POST /api/exams
    public function store(Request $request)
    {
        $validated = $request->validate([
            'title'     => 'required|string|max:255',
            'subject'   => 'nullable|string',
            'file_id'   => 'nullable|string',
            'file_name' => 'nullable|string',
            'questions' => 'nullable|array',
            'page_count' => 'nullable|integer',
        ]);

        $sheet = ExamSheet::create([
            ...$validated,
            'user_id'   => $request->user()->id,
            'questions' => $validated['questions'] ?? [],
        ]);

        return response()->json([
            'success' => true,
            'data'    => $sheet,
        ], 201);
    }

    // PUT /api/exams/{id}
    public function update(Request $request, $id)
    {
        $sheet = ExamSheet::where('_id', $id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (!$sheet) {
            return response()->json([
                'success' => false,
                'message' => 'Exam not found',
            ], 404);
        }

        $validated = $request->validate([
            'title'     => 'sometimes|string|max:255',
            'subject'   => 'nullable|string',
            'file_name' => 'nullable|string',
            'questions' => 'nullable|array',
            'pinned'    => 'sometimes|boolean', // ← أضف هذا
        ]);

        $sheet->update($validated);
        $sheet->refresh();  // ← مهم عشان يرجع البيانات المحدثة

        return response()->json([
            'success' => true,
            'data'    => $sheet,
        ]);
    }

    // DELETE /api/exams/{id}
    public function destroy(Request $request, $id)
    {
        $sheet = ExamSheet::where('_id', $id)
            ->where('user_id', $request->user()->id)
            ->first();

        if (!$sheet) {
            return response()->json([
                'success' => false,
                'message' => 'Exam not found',
            ], 404);
        }

        $sheet->delete();

        return response()->json([
            'success' => true,
            'message' => 'Exam deleted',
        ]);
    }

    // POST /api/files/{fileId}/exam-questions
    public function generateQuestions(Request $request, $fileId)
    {
        set_time_limit(0);

        $codeSubTypes = [
            'code_output', 'code_write', 'code_debug', 'code_explain',
            'code_complete', 'code_complexity', 'code_concept',
            'code_tracing', 'code_convert', 'sql_query',
        ];

        $validated = $request->validate([
            'type' => ['required', \Illuminate\Validation\Rule::in(array_merge([
                'multiple_choice', 'true_false', 'short_answer', 'essay',
                'fill_blank', 'matching', 'ordering', 'definition',
                'diagram', 'calculation', 'compare', 'case_study', 'code',
            ], $codeSubTypes))],
            'difficulty'       => ['required', \Illuminate\Validation\Rule::in(['easy', 'medium', 'hard'])],
            'count'            => ['required', 'integer', 'min:1', 'max:50'],
            'force_regenerate' => ['sometimes', 'boolean'],
            'from_page'        => ['sometimes', 'nullable', 'integer', 'min:1'],
            'to_page'          => ['sometimes', 'nullable', 'integer', 'min:1', 'gte:from_page'],
        ]);

        $filesController = app(\App\Http\Controllers\FilesController::class);
        return $filesController->examQuestions($request, $fileId);
    }
}