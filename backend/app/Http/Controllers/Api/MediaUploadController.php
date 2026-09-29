<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MediaUploadController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'file' => ['required', 'file', 'max:10240'], // 10MB
        ]);

        $file = $request->file('file');
        $path = $file->store('uploads', 'public');
        $url = Storage::disk('public')->url($path);

        $mime = $file->getMimeType() ?: '';
        $originalName = strtolower($file->getClientOriginalName() ?: '');
        $extension = strtolower($file->getClientOriginalExtension() ?: '');

        $isImage = str_starts_with($mime, 'image/')
            || in_array($extension, ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'], true)
            || preg_match('/\.(jpg|jpeg|png|gif|webp|heic|heif)$/', $originalName) === 1;
        $isVideo = str_starts_with($mime, 'video/')
            || in_array($extension, ['mp4', 'mov', 'm4v', 'avi', 'webm'], true);
        $isAudio = str_starts_with($mime, 'audio/')
            || in_array($extension, ['mp3', 'wav', 'm4a', 'aac', 'ogg'], true);

        $type = $isImage
            ? 'image'
            : ($isVideo ? 'video' : ($isAudio ? 'audio' : 'document'));

        return response()->json([
            'url' => $url,
            'type' => $type,
            'name' => $file->getClientOriginalName(),
            'size' => $file->getSize(),
            'mime_type' => $mime,
        ], 201);
    }
}
