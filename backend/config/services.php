<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
    ],
    
    'apple' => [
        'client_id' => env('APPLE_CLIENT_ID'), // Service ID (web) or Bundle ID depending on your Sign in with Apple setup
    ],

    'stripe' => [
        'secret' => env('STRIPE_SECRET'),
        'webhook_secret' => env('STRIPE_WEBHOOK_SECRET'),
    ],

    'paystack' => [
        'secret' => env('PAYSTACK_SECRET'),
        'webhook_secret' => env('PAYSTACK_WEBHOOK_SECRET'),
    ],

    'flutterwave' => [
        'secret' => env('FLUTTERWAVE_SECRET'),
        'webhook_secret' => env('FLUTTERWAVE_WEBHOOK_SECRET'),
    ],
    'paypal' => [
        'mode' => env('PAYPAL_MODE', 'live'),
        'webhook_id' => env('PAYPAL_WEBHOOK_ID'),
    ],

    'agora' => [
        'app_id' => env('AGORA_APP_ID', 'ce87ef837009421c8c06f126feba66e3'),
        'app_certificate' => env('AGORA_APP_CERTIFICATE'),
    ],

    'firebase' => [
        'project_id' => env('FIREBASE_PROJECT_ID'),
        'client_email' => env('FIREBASE_CLIENT_EMAIL'),
        'private_key' => env('FIREBASE_PRIVATE_KEY'),
        'credentials_json' => env('FIREBASE_CREDENTIALS_JSON'),
    ],

];
