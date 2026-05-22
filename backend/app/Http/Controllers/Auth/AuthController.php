<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Storage;
use App\Http\Controllers\OtpController;

class AuthController extends Controller
{
    // ────────────────────────────────────────────────────────
    //  POST /auth/signup
    // ────────────────────────────────────────────────────────
    public function signup(Request $request)
    {
        $data = $request->validate([
            'name'     => ['required', 'string', 'max:255'],
            'email'    => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $user = User::create([
            'name'     => $data['name'],
            'email'    => $data['email'],
            'password' => Hash::make($data['password']),
        ]);

        $token = auth()->login($user);

        return response()->json([
            'success' => true,
            'message' => 'Registered successfully',
            'data'    => [
                'token'      => $token,
                'expires_in' => auth()->factory()->getTTL() * 60,
                'user'       => $this->formatUser($user),
            ],
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/login
    // ────────────────────────────────────────────────────────
    public function login(Request $request)
{
    $data = $request->validate([
        'email'    => ['required', 'email'],
        'password' => ['required', 'string'],
    ], [
        'email.required' => 'Email is required',
        'email.email'    => 'Please enter a valid email address',
        'password.required' => 'Password is required',
    ]);

    // ✅ تحقق من صيغة الإيميل (لازم gmail.com أو domain معين)
    $emailDomain = strtolower(substr(strrchr($data['email'], "@"), 1));
    $allowedDomains = ['gmail.com', 'yahoo.com', 'outlook.com']; // أضف الـ domains المسموحة
    
    if (!in_array($emailDomain, $allowedDomains)) {
        return response()->json([
            'success' => false,
            'message' => 'Please use a valid email domain (gmail.com, yahoo.com, outlook.com)',
        ], 422);
    }

    $user = User::where('email', $data['email'])->first();

    if (!$user) {
        return response()->json([
            'success' => false,
            'message' => 'No account found with this email. Please sign up first',
        ], 401);
    }

    if (!Hash::check($data['password'], $user->password)) {
        return response()->json([
            'success' => false,
            'message' => 'Wrong password',
        ], 401);
    }

    $token = auth()->login($user);

    return response()->json([
        'success' => true,
        'message' => 'Login success',
        'data'    => [
            'token'      => $token,
            'expires_in' => auth()->factory()->getTTL() * 60,
            'user'       => $this->formatUser($user),
        ],
    ]);
}

    // ────────────────────────────────────────────────────────
    //  POST /auth/logout
    // ────────────────────────────────────────────────────────
    public function logout(Request $request)
    {
        auth()->logout();

        return response()->json([
            'success' => true,
            'message' => 'Logged out',
            'data'    => (object) [],
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/refresh
    // ────────────────────────────────────────────────────────
    public function refresh(Request $request)
    {
        try {
            $token = auth()->parseToken()->refresh();
            $user  = auth()->setToken($token)->user();

            return response()->json([
                'success' => true,
                'message' => 'OK',
                'data'    => [
                    'token'      => $token,
                    'expires_in' => auth()->factory()->getTTL() * 60,
                    'user'       => $this->formatUser($user),
                ],
            ]);
        } catch (\Tymon\JWTAuth\Exceptions\TokenExpiredException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Refresh token expired, please login again',
            ], 401);
        } catch (\Tymon\JWTAuth\Exceptions\TokenInvalidException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Token invalid',
            ], 401);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Token not found',
            ], 401);
        }
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/forgot-password
    // ────────────────────────────────────────────────────────
    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => ['required', 'email'],
        ]);

        // ✅ تحقق من صيغة الإيميل
        $emailDomain = strtolower(substr(strrchr($request->email, "@"), 1));
        $allowedDomains = ['gmail.com', 'yahoo.com', 'outlook.com'];
        
        if (!in_array($emailDomain, $allowedDomains)) {
            return response()->json([
                'success' => false,
                'message' => 'Please use a valid email domain (gmail.com, yahoo.com, outlook.com)',
            ], 422);
        }

        if (!User::where('email', $request->email)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'User not found',
            ], 404);
        }

        $otpController = new OtpController();
        return $otpController->sendOtpForPasswordReset($request);
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/reset-password
    // ────────────────────────────────────────────────────────
    public function resetPassword(Request $request)
    {
        $request->validate([
            'email'    => ['required', 'email'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        $email = $request->email;

        $user = User::where('email', $email)->first();
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found.',
            ], 404);
        }

        $isVerified = Cache::get('verified_' . $email);
        if (!$isVerified) {
            return response()->json([
                'success' => false,
                'message' => 'Email not verified. Please verify your OTP first.',
            ], 422);
        }

        $user->password = Hash::make($request->password);
        $user->save();
        Cache::forget('verified_' . $email);

        return response()->json([
            'success' => true,
            'message' => 'Password reset successfully',
            'data'    => (object) [],
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  GET /me
    // ────────────────────────────────────────────────────────
    public function me(Request $request)
    {
        return response()->json([
            'success' => true,
            'message' => 'OK',
            'data'    => $this->formatUser($request->user()),
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  PUT /me
    // ────────────────────────────────────────────────────────
    public function updateProfile(Request $request)
    {
        // ✅ ضروري عشان Laravel يشوف الـ files في PUT/PATCH
        $data = $request->validate([
            'name'  => ['sometimes', 'string', 'max:255'],
            'image' => ['sometimes', 'image', 'mimes:jpeg,png,jpg,webp', 'max:2048'],
        ]);

        $user = $request->user();

        if (isset($data['name'])) {
            $user->name = $data['name'];
        }

        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('avatars', 'public');
            $user->image = $path;
        }

        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'OK',
            'data'    => $this->formatUser($user),
        ]);
    }

    public function deleteAvatar(Request $request)
    {
        $user = $request->user();

        if ($user->image) {
            Storage::disk('public')->delete($user->image);
            $user->image = null;
            $user->save();
        }

        return response()->json([
            'success' => true,
            'message' => 'Avatar removed',
            'data'    => $this->formatUser($user),
        ]);
    }

    public function deleteAccount(Request $request)
    {
        $user = auth()->user();
        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Unauthorized'], 401);
        }
        foreach ($user->files as $file) {
            $file->summaries()->delete();
            $file->questions()->delete();
            $file->explanations()->delete();
            $file->delete();
        }
        $user->delete();
        return response()->json(['success' => true, 'message' => 'Account deleted successfully']);
    }

    // ────────────────────────────────────────────────────────
    //  Helper
    // ────────────────────────────────────────────────────────
    private function formatUser($user): array
    {
        return [
            'id'        => (string) $user->id,
            'name'      => $user->name,
            'email'     => $user->email,
            'language'  => $user->language ?? 'en',
            'theme'     => $user->theme    ?? 'system',
            // ✅ بيرجع الـ full URL أو null لو مفيش صورة
            'image_url' => $user->image_url,
        ];
    }

    // ────────────────────────────────────────────────────────
    //  PUT /me — update name only
    // ────────────────────────────────────────────────────────
    public function updateName(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
        ]);

        $user = $request->user();
        $user->name = trim($data['name']);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Name updated',
            'data'    => $this->formatUser($user),
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/change-email/send-otp
    // ────────────────────────────────────────────────────────
    public function changeEmailSendOtp(Request $request)
    {
        $data = $request->validate([
            'new_email' => ['required', 'email', 'max:255'],
            'password'  => ['required', 'string'],
        ]);

        $user = $request->user();

        if (!\Illuminate\Support\Facades\Hash::check($data['password'], $user->password)) {
            return response()->json(['success' => false, 'message' => 'Wrong password'], 422);
        }

        if (\App\Models\User::where('email', $data['new_email'])->exists()) {
            return response()->json(['success' => false, 'message' => 'Email already in use'], 422);
        }

        $otp = str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
        \Illuminate\Support\Facades\Cache::put('email_change_otp_' . $user->id, [
            'otp'       => $otp,
            'new_email' => $data['new_email'],
        ], now()->addMinutes(10));

        try {
            \Illuminate\Support\Facades\Mail::send(
                'emails.otp',
                ['otp' => $otp, 'email' => $data['new_email']],
                fn($m) => $m->to($data['new_email'])->subject('Email Change Verification')
            );
        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Cache::forget('email_change_otp_' . $user->id);
            return response()->json(['success' => false, 'message' => 'Failed to send OTP'], 500);
        }

        return response()->json(['success' => true, 'message' => 'OTP sent to new email']);
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/change-email/verify
    // ────────────────────────────────────────────────────────
    public function changeEmailVerify(Request $request)
    {
        $data = $request->validate([
            'otp' => ['required', 'string', 'size:6'],
        ]);

        $user    = $request->user();
        $cached  = \Illuminate\Support\Facades\Cache::get('email_change_otp_' . $user->id);

        if (!$cached) {
            return response()->json(['success' => false, 'message' => 'OTP expired'], 400);
        }

        if ((string) $cached['otp'] !== (string) $data['otp']) {
            return response()->json(['success' => false, 'message' => 'Invalid OTP'], 400);
        }

        $user->email = $cached['new_email'];
        $user->save();

        \Illuminate\Support\Facades\Cache::forget('email_change_otp_' . $user->id);

        return response()->json([
            'success' => true,
            'message' => 'Email updated',
            'data'    => $this->formatUser($user),
        ]);
    }

    // ────────────────────────────────────────────────────────
    //  POST /auth/change-password
    // ────────────────────────────────────────────────────────
    public function changePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'new_password'     => ['required', 'string', 'min:8'],
        ]);

        $user = $request->user();

        if (!\Illuminate\Support\Facades\Hash::check($data['current_password'], $user->password)) {
            return response()->json(['success' => false, 'message' => 'Wrong current password'], 422);
        }

        $user->password = \Illuminate\Support\Facades\Hash::make($data['new_password']);
        $user->save();

        return response()->json(['success' => true, 'message' => 'Password updated']);
    }
}