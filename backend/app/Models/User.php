<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Contracts\Auth\MustVerifyEmail;

class User extends Authenticatable implements MustVerifyEmail
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'institution_id',
        'status',
        'suspended_at',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'suspended_at' => 'datetime',
        ];
    }

    public function institution() {
        return $this->belongsTo(\App\Models\Institution::class);
    }

    public function profile() {
        return $this->hasOne(\App\Models\Profile::class);
    }

    public function socialAccounts() { return $this->hasMany(\App\Models\SocialAccount::class); }

    public function memberships()
    {
        return $this->hasMany(InstitutionMembership::class);
    }

    public function yearGroupMemberships()
    {
        return $this->hasMany(InstitutionYearGroupMembership::class);
    }

    public function createdYearGroups()
    {
        return $this->hasMany(InstitutionYearGroup::class, 'created_by');
    }

    public function posts()
    {
        return $this->hasMany(Post::class);
    }

    public function stories()
    {
        return $this->hasMany(Story::class);
    }

    public function announcements()
    {
        return $this->hasMany(Announcement::class, 'created_by');
    }

    public function events()
    {
        return $this->hasMany(Event::class, 'created_by');
    }

    public function eventRsvps()
    {
        return $this->hasMany(EventRsvp::class);
    }

    public function sentConnectionRequests()
    {
        return $this->hasMany(ConnectionRequest::class, 'from_user_id');
    }

    public function receivedConnectionRequests()
    {
        return $this->hasMany(ConnectionRequest::class, 'to_user_id');
    }

    public function sentMessages()
    {
        return $this->hasMany(DirectMessage::class, 'sender_id');
    }

    public function receivedMessages()
    {
        return $this->hasMany(DirectMessage::class, 'recipient_id');
    }

    public function blocks()
    {
        return $this->hasMany(UserBlock::class, 'blocker_id');
    }

    public function mutes()
    {
        return $this->hasMany(UserMute::class, 'user_id');
    }

    public function notifications()
    {
        return $this->hasMany(UserNotification::class);
    }

    public function notificationPreference()
    {
        return $this->hasOne(NotificationPreference::class);
    }

    public function paymentTransactions()
    {
        return $this->hasMany(PaymentTransaction::class);
    }

    public function donationCampaigns()
    {
        return $this->hasMany(DonationCampaign::class, 'created_by');
    }

    public function donations()
    {
        return $this->hasMany(Donation::class);
    }

    public function subscriptions()
    {
        return $this->hasMany(Subscription::class);
    }

    public function ads()
    {
        return $this->hasMany(Ad::class, 'advertiser_id');
    }

}
