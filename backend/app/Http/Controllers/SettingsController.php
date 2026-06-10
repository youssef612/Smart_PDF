<?php

namespace App\Http\Controllers;
use Illuminate\Support\Facades\Hash;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SettingsController extends Controller
{
    public function changeLanguage(Request $request)
    {
        // Swagger: required language enum [ar, en]
        $data = $request->validate([
            'language' => ['required', Rule::in(['ar', 'en'])],
        ]);

        $user = $request->user();
        $user->language = $data['language'];
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'OK',
            'data' => (object)[],
        ], 200);
    }

    
public function changeTheme(Request $request)
{
    // Swagger: required theme enum [system, light, dark]
    $data = $request->validate([
        'theme' => ['required', Rule::in(['system', 'light', 'dark'])],
    ]);

    $user = $request->user();
    $user->theme = $data['theme'];
    $user->save();

    return response()->json([
        'success' => true,
        'message' => 'OK',
        'data' => (object)[],
    ], 200);

}
    public function changeEmail(Request $request)
    {
        $data = $request->validate([
            'new_email'       => ['required', 'email', 'unique:users,email'],
            'current_password' => ['required', 'string'],
        ]);
        $user = $request->user();
        if (!\Illuminate\Support\Facades\Hash::check($data['current_password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect.',
            ], 422);
        }
        $user->email = $data['new_email'];
        $user->save();
        return response()->json([
            'success' => true,
            'message' => 'Email updated. Please login again.',
            'data'    => (object)[],
        ]);
    }


public function changePassword(Request $request)
{
 
    $data = $request->validate([
        'current_password' => ['required', 'string'],
        'new_password' => ['required', 'string', 'min:8', 'confirmed'],
    ]);

    $user = $request->user();

    if (!Hash::check($data['current_password'], $user->password)) {
        return response()->json([
            'success' => false,
            'message' => 'Validation error',
            'errors' => [
                'current_password' => ['Current password is incorrect.'],
            ],
        ], 422);
    }


    $user->password = Hash::make($data['new_password']);
    $user->save();

  
    auth()->logout();
    
    return response()->json([
        'success' => true,
        'message' => 'Password changed. Please login again.',
        'data' => (object)[],
    ], 200);
}

}