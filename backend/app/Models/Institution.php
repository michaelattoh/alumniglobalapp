<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Institution extends Model
{
    protected $fillable = [
        'name',
        'school_id',
        'slug',
        'status',
        'logo_url',
        'banner_url',
        'website',
        'email',
        'phone',
        'location',
        'address',
        'motto',
        'description',
    ];

    public function users() {
        return $this->hasMany(User::class);
    }

    public function invitationCodes() {
        return $this->hasMany(InvitationCode::class);
    }

    public function memberships()
    {
        return $this->hasMany(InstitutionMembership::class);
    }

    public function yearGroups()
    {
        return $this->hasMany(InstitutionYearGroup::class);
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
        return $this->hasMany(Announcement::class);
    }

    public function events()
    {
        return $this->hasMany(Event::class);
    }

    public function donationCampaigns()
    {
        return $this->hasMany(DonationCampaign::class);
    }

    public function paymentTransactions()
    {
        return $this->hasMany(PaymentTransaction::class);
    }

    public function paymentSetting()
    {
        return $this->hasOne(InstitutionPaymentSetting::class);
    }

    public function emailSetting()
    {
        return $this->hasOne(InstitutionEmailSetting::class);
    }
}
