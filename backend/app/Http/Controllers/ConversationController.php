<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Conversation;
use App\Models\ConversationMessage;
use App\Models\File;
use Illuminate\Support\Facades\Http;

class ConversationController extends Controller
{
    // ────────────────────────────────────────────────────────
    //  GET /conversations (جلب لستة المحادثات مع حساب الرسايل)
    // ────────────────────────────────────────────────────────
    public function index()
    {
        $conversations = Conversation::where('user_id', auth()->id())
            ->with('messages')
            ->latest()
            ->get();

        // ✅ رتب في PHP: الـ pinned فوق، وجوا كل group الأحدث أول
        $conversations = $conversations->sortByDesc(function ($conv) {
            return [
                $conv->is_pinned ? 1 : 0,
                $conv->updated_at?->timestamp ?? 0,
            ];
        })->values();

        $formattedConversations = $conversations->map(function ($conversation) {
            return [
                'id'             => (string) $conversation->_id,
                'user_id'        => $conversation->user_id,
                'title'          => $conversation->title ?? 'New Chat',
                'type'           => $conversation->type ?? 'general',
                'file_id'        => $conversation->file_id ? (string) $conversation->file_id : null,
                'is_pinned'      => (bool) ($conversation->is_pinned ?? false), // ✅ ضيف الفيلد
                'messages_count' => $conversation->messages ? $conversation->messages->count() : 0,
                'created_at'     => $conversation->created_at?->toISOString(),
                'updated_at'     => $conversation->updated_at?->toISOString(),
            ];
        });

        return response()->json([
            'success' => true,
            'data'    => $formattedConversations,
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /conversations (إنشاء محادثة جديدة وتثبيت الـ ID)
    // ────────────────────────────────────────────────────────
    public function store(Request $request)
    {
        $conversation = Conversation::create([
            'user_id' => auth()->id(),
            'title'   => $request->title ?? 'New Chat',
            'type'    => $request->type ?? 'general',
            'file_id' => $request->file_id ?? null,
        ]);

        // نقوم بعمل format فوري للـ ID حتى يأخذه الفلاتر مباشرة ويكمل الشات عليه
        $formatted = [
            'id'      => (string) $conversation->_id,
            'user_id' => $conversation->user_id,
            'title'   => $conversation->title,
            'type'    => $conversation->type,
            'file_id' => $conversation->file_id,
        ];

        return response()->json([
            'success' => true,
            'data'    => $formatted
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  GET /conversations/{id} (فتح محادثة معينة برسايلها)
    // ────────────────────────────────────────────────────────
    public function show($id)
    {
        $conversation = Conversation::where('user_id', auth()->id())
            ->with(['messages' => function($q) {
                $q->orderBy('created_at', 'asc'); // ترتيب الرسايل تصاعدياً من الأقدم للأحدث للشاشة
            }])
            ->findOrFail($id);

        $formattedMessages = $conversation->messages->map(function ($msg) {
            return [
                'id'      => (string) $msg->_id,
                'role'    => $msg->role,
                'content' => $msg->content,
            ];
        })->values()->toArray();

        $formattedConversation = [
            'id'       => (string) $conversation->_id,
            'title'    => $conversation->title,
            'type'     => $conversation->type,
            'file_id'  => $conversation->file_id ? (string) $conversation->file_id : null,
            'messages' => $formattedMessages,
        ];

        return response()->json([
            'success' => true,
            'data'    => $formattedConversation
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  DELETE /conversations/{id} (مسح محادثة)
    // ────────────────────────────────────────────────────────
    public function destroy($id)
    {
        $conversation = Conversation::where('user_id', auth()->id())
            ->findOrFail($id);
        
        // المونجو سيتكفل بحذف الرسايل التابعة لو ضبطت الـ cascade أو نمسحهم يدوياً احتياطاً
        ConversationMessage::where('conversation_id', $id)->delete();
        $conversation->delete();

        return response()->json([
            'success' => true,
            'message' => 'Conversation deleted'
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  PATCH /conversations/{id} (إعادة تسمية محادثة)
    // ────────────────────────────────────────────────────────
    public function update(Request $request, $id)
    {
        $request->validate([
            'title' => 'required|string|max:100',
        ]);

        $conversation = Conversation::where('user_id', auth()->id())
            ->findOrFail($id);

        $conversation->update([
            'title' => trim($request->title),
        ]);

        return response()->json([
            'success' => true,
            'data'    => [
                'id'    => (string) $conversation->_id,
                'title' => $conversation->title,
            ]
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  PATCH /conversations/{id}/pin
    // ────────────────────────────────────────────────────────
    public function pin($id)
    {
        $conversation = Conversation::where('user_id', auth()->id())
            ->findOrFail($id);

        $newPinState = !($conversation->is_pinned ?? false);
        
        $conversation->is_pinned = $newPinState;
        $conversation->save();

        // تحقق إن الحفظ اتعمل فعلاً
        $fresh = $conversation->fresh();
        
        \Illuminate\Support\Facades\Log::info('PIN DEBUG', [
            'id'        => $id,
            'new_state' => $newPinState,
            'saved'     => $fresh->is_pinned,
        ]);

        return response()->json([
            'success'   => true,
            'is_pinned' => (bool) $fresh->is_pinned,
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /conversations/{id}/chat (المحرك الأساسي للشات)
    // ────────────────────────────────────────────────────────
    public function chat(Request $request, $id)
    {
        $request->validate(['message' => 'required|string|max:2000']);

        $conversation = Conversation::where('user_id', auth()->id())
            ->findOrFail($id);

        // 1. حفظ رسالة المستخدم في الداتابيز
        $conversation->messages()->create([
            'role'    => 'user',
            'content' => $request->message,
        ]);

        // 2. سحب الـ history كامل من الداتابيز وترتيبه أوتوماتيك للبرومبت
        $history = ConversationMessage::where('conversation_id', $id)
            ->orderBy('created_at', 'asc')
            ->get()
            ->map(fn($m) => ['role' => $m->role, 'content' => $m->content])
            ->toArray();

        // 3. تمرير الـ Fake Request للـ FilesController لتوليد الرد الذكي
        $filesController = new \App\Http\Controllers\FilesController();
        $fakeRequest = new \Illuminate\Http\Request();
        $fakeRequest->merge([
            'message' => $request->message,
            'history' => $history,
        ]);

        // فحص وضع الشات: مستندات أم عام
        if ($conversation->file_id) {
            $response = $filesController->chat($fakeRequest, $conversation->file_id);
        } else {
            $response = $filesController->generalChat($fakeRequest);
        }

        $data = $response->getData(true);

        if (!($data['success'] ?? false)) {
            return response()->json(['success' => false, 'message' => 'Model failed to generate response'], 500);
        }

        $reply = $data['data']['reply'];

        // 4. حفظ رد الـ AI في الداتابيز مع سياق المحادثة
        $conversation->messages()->create([
            'role'    => 'assistant',
            'content' => $reply,
        ]);

        // 5. تحديث التايتل تلقائياً بأول رسالة لو لسه شات جديد
        $totalMessagesCount = ConversationMessage::where('conversation_id', $id)->count();
        if ($totalMessagesCount <= 2) {
            $conversation->update([
                'title' => mb_substr($request->message, 0, 50),
            ]);
        }

        return response()->json([
            'success' => true, 
            'data'    => ['reply' => $reply]
        ]);
    }
}