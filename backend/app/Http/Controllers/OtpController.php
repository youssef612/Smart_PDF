<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class OtpController extends Controller
{
    /**
     * Generate a 6-digit OTP as string (avoid integer/string type mismatch on compare)
     */
    private function generateOtp(): string
    {
        return str_pad((string) random_int(100000, 999999), 6, '0', STR_PAD_LEFT);
    }

    public function sendOtpForPasswordReset(Request $request)
    {
        $email = $request->email;
        $otp = $this->generateOtp();
        Cache::put("otp_" . $email, $otp, now()->addMinutes(10));
        try {
            Mail::send("emails.otp", ["otp" => $otp, "email" => $email], function ($message) use ($email) {
                $message->to($email)->subject("Your Verification Code");
            });
        } catch (\Exception $e) {
            return response()->json(["success" => false, "message" => "Failed to send OTP"], 500);
        }
        return response()->json(["success" => true, "message" => "OTP sent successfully"]);
    }

    public function sendOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        $email = $request->email;
        // Check if email already registered
        if (\App\Models\User::where('email', $email)->exists()) {
            return response()->json([
                'success' => false,
                'message' => 'Email already registered. Please sign in.',
            ], 422);
        }
        $otp   = $this->generateOtp();

        // Store as string explicitly
        Cache::put('otp_' . $email, $otp, now()->addMinutes(10));

        try {
            Mail::send(
                'emails.otp',
                ['otp' => $otp, 'email' => $email],
                function ($message) use ($email) {
                    $message->to($email)->subject('Your Verification Code');
                }
            );

            return response()->json([
                'success' => true,
                'message' => 'OTP sent successfully',
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to send OTP: ' . $e->getMessage());

            // Remove the cached OTP so the user can try again cleanly
            Cache::forget('otp_' . $email);

            return response()->json([
                'success' => false,
                'message' => 'Failed to send OTP. Please try again.',
            ], 500);
        }
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp'   => 'required|string|size:6',
        ]);

        $email = $request->email;
        $otp   = $request->otp;

        $cachedOtp = Cache::get('otp_' . $email);

        if ($cachedOtp === null) {
            return response()->json([
                'success' => false,
                'message' => 'OTP expired or not found. Please request a new code.',
            ], 400);
        }

        // Strict string comparison — both sides are now strings
        if ((string) $cachedOtp !== (string) $otp) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid OTP. Please try again.',
            ], 400);
        }

        // Mark email as verified for 30 minutes
        Cache::put('verified_' . $email, true, now()->addMinutes(30));

        // Delete OTP so it cannot be reused
        Cache::forget('otp_' . $email);

        return response()->json([
            'success' => true,
            'message' => 'OTP verified successfully',
        ]);
    }

    public function resendOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        $email    = $request->email;
        $lastSent = Cache::get('otp_last_sent_' . $email);

        if ($lastSent && now()->diffInSeconds($lastSent) < 30) {
            return response()->json([
                'success' => false,
                'message' => 'Please wait 30 seconds before requesting a new code.',
            ], 429);
        }

        $otp = $this->generateOtp();

        Cache::put('otp_' . $email, $otp, now()->addMinutes(10));
        Cache::put('otp_last_sent_' . $email, now(), now()->addMinutes(1));

        try {
            Mail::send(
                'emails.otp',
                ['otp' => $otp, 'email' => $email],
                function ($message) use ($email) {
                    $message->to($email)->subject('Your Verification Code');
                }
            );

            return response()->json([
                'success' => true,
                'message' => 'OTP resent successfully',
            ]);
        } catch (\Exception $e) {
            Log::error('Failed to resend OTP: ' . $e->getMessage());

            Cache::forget('otp_' . $email);
            Cache::forget('otp_last_sent_' . $email);

            return response()->json([
                'success' => false,
                'message' => 'Failed to resend OTP. Please try again.',
            ], 500);
        }
    }
}