<?php

namespace App\Services;

use App\Models\AiControl;
use App\Models\ConnectionRequest;
use App\Models\Event;
use App\Models\NotificationPreference;
use App\Models\Post;
use App\Models\RecommendationIgnore;
use App\Models\Recommendation;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Support\Collection;

class RecommendationService
{
    public function refresh(User $user, string $type, int $limit = 20): void
    {
        if (!$this->aiEnabled()) {
            return;
        }

        $preference = NotificationPreference::query()->where('user_id', $user->id)->value('ai_personalization_enabled');
        if ($preference === false) {
            return;
        }

        $control = AiControl::first();
        if ($control && !$control->recommendations_enabled) {
            return;
        }

        $this->generate($user, $type, $limit);
    }

    public function generate(User $user, string $type, int $limit = 20): void
    {
        if ($type === 'event') {
            $this->generateEventRecommendations($user, $limit);
            return;
        }

        if ($type === 'connection') {
            $this->generateConnectionRecommendations($user, $limit);
            return;
        }

        $this->generateContentRecommendations($user, $limit);
    }

    private function generateContentRecommendations(User $user, int $limit): void
    {
        $keywords = $this->profileKeywords($user);
        $ignoredIds = RecommendationIgnore::query()
            ->where('user_id', $user->id)
            ->where('entity_type', 'post')
            ->pluck('entity_id')
            ->all();

        $posts = Post::query()
            ->withCount(['comments', 'reactions', 'saves'])
            ->where(function ($q) {
                $q->whereNull('scheduled_at')
                  ->orWhere('scheduled_at', '<=', now());
            })
            ->when(!empty($ignoredIds), function ($q) use ($ignoredIds) {
                $q->whereNotIn('id', $ignoredIds);
            })
            ->when($user->role !== 'super_admin', function ($q) use ($user) {
                $q->where(function ($visibility) use ($user) {
                    $visibility->where('visibility', 'public');
                    if ($user->institution_id) {
                        $visibility->orWhere(function ($sub) use ($user) {
                            $sub->where('visibility', 'institution_only')
                                ->where('institution_id', $user->institution_id);
                        });
                    }
                });
            })
            ->latest()
            ->limit(200)
            ->get();

        if ($posts->isEmpty()) {
            return;
        }

        $engagementScores = $posts->map(function (Post $post) {
            return ($post->reactions_count ?? 0)
                + ($post->comments_count ?? 0) * 2
                + ($post->saves_count ?? 0) * 3;
        });

        $maxEngagement = max(1, (int) $engagementScores->max());

        $scored = $posts->map(function (Post $post) use ($user, $keywords, $maxEngagement) {
            $engagement = ($post->reactions_count ?? 0)
                + ($post->comments_count ?? 0) * 2
                + ($post->saves_count ?? 0) * 3;
            $engagementScore = $engagement / $maxEngagement;

            $daysAgo = max(0, now()->diffInDays($post->created_at));
            $recencyScore = max(0, 30 - $daysAgo) / 30;

            $institutionScore = ($user->institution_id && (int) $post->institution_id === (int) $user->institution_id) ? 0.6 : 0;

            $content = strtolower((string) $post->content);
            $keywordHits = 0;
            foreach ($keywords as $keyword) {
                if ($keyword !== '' && str_contains($content, $keyword)) {
                    $keywordHits++;
                }
            }
            $keywordScore = min(0.9, $keywordHits * 0.3);

            $score = (0.4 * $engagementScore) + (0.3 * $recencyScore) + (0.2 * $institutionScore) + (0.1 * $keywordScore);

            $reason = 'Trending now';
            if ($institutionScore > 0) {
                $reason = 'Popular at your institution';
            } elseif ($keywordScore > 0) {
                $reason = 'Matches your interests';
            }

            return [
                'post' => $post,
                'score' => round($score, 4),
                'reason' => $reason,
            ];
        })
            ->sortByDesc('score')
            ->take($limit);

        $this->upsertRecommendations($user->id, 'content', 'post', $scored->pluck('post'), $scored);
    }

    private function generateEventRecommendations(User $user, int $limit): void
    {
        $keywords = $this->profileKeywords($user);
        $ignoredIds = RecommendationIgnore::query()
            ->where('user_id', $user->id)
            ->where('entity_type', 'event')
            ->pluck('entity_id')
            ->all();

        $events = Event::query()
            ->where('starts_at', '>=', now())
            ->when(!empty($ignoredIds), function ($q) use ($ignoredIds) {
                $q->whereNotIn('id', $ignoredIds);
            })
            ->orderBy('starts_at')
            ->limit(200)
            ->get();

        if ($events->isEmpty()) {
            return;
        }

        $scored = $events->map(function (Event $event) use ($user, $keywords) {
            $daysUntil = max(0, now()->diffInDays($event->starts_at));
            $timeScore = 1 - min(1, $daysUntil / 60);

            $institutionScore = ($user->institution_id && (int) $event->institution_id === (int) $user->institution_id) ? 0.6 : 0;

            $text = strtolower(trim(($event->title ?? '') . ' ' . ($event->description ?? '') . ' ' . ($event->event_type ?? '')));
            $keywordHits = 0;
            foreach ($keywords as $keyword) {
                if ($keyword !== '' && str_contains($text, $keyword)) {
                    $keywordHits++;
                }
            }
            $keywordScore = min(0.9, $keywordHits * 0.3);

            $locationScore = 0;
            if (!empty($user->profile?->location) && !empty($event->location)) {
                if (stripos($event->location, $user->profile->location) !== false) {
                    $locationScore = 0.2;
                }
            }

            $score = (0.4 * $timeScore) + (0.3 * $institutionScore) + (0.2 * $keywordScore) + (0.1 * $locationScore);

            $reason = 'Upcoming event';
            if ($institutionScore > 0) {
                $reason = 'Hosted by your institution';
            } elseif ($keywordScore > 0) {
                $reason = 'Matches your interests';
            }

            return [
                'event' => $event,
                'score' => round($score, 4),
                'reason' => $reason,
            ];
        })
            ->sortByDesc('score')
            ->take($limit);

        $this->upsertRecommendations($user->id, 'event', 'event', $scored->pluck('event'), $scored);
    }

    private function generateConnectionRecommendations(User $user, int $limit): void
    {
        $keywords = $this->profileKeywords($user);
        $skillSet = $this->profileSkillSet($user);
        $ignoredIds = RecommendationIgnore::query()
            ->where('user_id', $user->id)
            ->where('entity_type', 'user')
            ->pluck('entity_id')
            ->all();

        $pendingOrConnected = ConnectionRequest::query()
            ->where(function ($q) use ($user) {
                $q->where('from_user_id', $user->id)
                    ->orWhere('to_user_id', $user->id);
            })
            ->get(['from_user_id', 'to_user_id']);

        $pendingOrConnectedIds = $pendingOrConnected
            ->pluck('from_user_id')
            ->merge($pendingOrConnected->pluck('to_user_id'))
            ->unique()
            ->filter()
            ->values()
            ->all();

        $candidates = User::query()
            ->with('profile')
            ->where('id', '!=', $user->id)
            ->when($user->institution_id, function ($q) use ($user) {
                $q->where('institution_id', $user->institution_id);
            })
            ->when(!empty($ignoredIds), function ($q) use ($ignoredIds) {
                $q->whereNotIn('id', $ignoredIds);
            })
            ->whereNotIn('id', $pendingOrConnectedIds)
            ->limit(200)
            ->get();

        if ($candidates->isEmpty()) {
            return;
        }

        $scored = $candidates->map(function (User $target) use ($user, $keywords, $skillSet) {
            $profile = $target->profile;
            $matchScore = 0;

            if ($user->institution_id && (int) $target->institution_id === (int) $user->institution_id) {
                $matchScore += 0.6;
            }

            if ($user->profile?->graduation_year && $profile?->graduation_year) {
                if ((int) $user->profile->graduation_year === (int) $profile->graduation_year) {
                    $matchScore += 0.3;
                }
            }

            if (!empty($user->profile?->department) && !empty($profile?->department)) {
                if (strcasecmp($user->profile->department, $profile->department) === 0) {
                    $matchScore += 0.2;
                }
            }

            $locationScore = 0;
            if (!empty($user->profile?->location) && !empty($profile?->location)) {
                if (stripos($profile->location, $user->profile->location) !== false) {
                    $locationScore = 0.2;
                }
            }

            $targetSkills = collect($profile?->skills ?? [])->map(fn ($s) => strtolower(trim((string) $s)))->filter();
            $overlap = $targetSkills->intersect($skillSet);
            $skillScore = min(0.6, $overlap->count() * 0.2);

            $text = strtolower(trim(($profile?->program ?? '') . ' ' . ($profile?->department ?? '') . ' ' . ($profile?->headline ?? '')));
            $keywordHits = 0;
            foreach ($keywords as $keyword) {
                if ($keyword !== '' && str_contains($text, $keyword)) {
                    $keywordHits++;
                }
            }
            $keywordScore = min(0.6, $keywordHits * 0.2);

            $score = round((0.5 * $matchScore) + (0.3 * $skillScore) + (0.1 * $keywordScore) + (0.1 * $locationScore), 4);

            $reason = 'Suggested connection';
            if ($matchScore >= 0.6) {
                $reason = 'Shared alumni context';
            } elseif ($skillScore > 0) {
                $reason = 'Similar skills';
            }

            return [
                'user' => $target,
                'score' => $score,
                'reason' => $reason,
            ];
        })
            ->sortByDesc('score')
            ->take($limit);

        $this->upsertRecommendations($user->id, 'connection', 'user', $scored->pluck('user'), $scored);
    }

    private function upsertRecommendations(int $userId, string $type, string $entityType, Collection $entities, Collection $scored): void
    {
        $existing = Recommendation::query()
            ->where('user_id', $userId)
            ->where('type', $type)
            ->get()
            ->keyBy('entity_id');

        $keepIds = [];

        foreach ($scored as $item) {
            $entity = $item[$entityType === 'post' ? 'post' : ($entityType === 'event' ? 'event' : 'user')];
            if (!$entity) {
                continue;
            }
            $keepIds[] = $entity->id;
            Recommendation::updateOrCreate(
                [
                    'user_id' => $userId,
                    'type' => $type,
                    'entity_type' => $entityType,
                    'entity_id' => $entity->id,
                ],
                [
                    'score' => $item['score'],
                    'source_model' => 'rules-v1',
                    'reason' => $item['reason'],
                ]
            );
        }

        if (!empty($keepIds)) {
            Recommendation::query()
                ->where('user_id', $userId)
                ->where('type', $type)
                ->whereNotIn('entity_id', $keepIds)
                ->delete();
        }
    }

    private function profileKeywords(User $user): array
    {
        $profile = $user->profile;
        $keywords = collect([
            $profile?->department,
            $profile?->program,
            $profile?->current_company,
            $profile?->current_role,
        ])
            ->filter()
            ->map(fn ($value) => strtolower(trim((string) $value)))
            ->values();

        $skillKeywords = collect($profile?->skills ?? [])
            ->map(fn ($value) => strtolower(trim((string) $value)))
            ->filter();

        return $keywords->merge($skillKeywords)->unique()->values()->all();
    }

    private function profileSkillSet(User $user): Collection
    {
        return collect($user->profile?->skills ?? [])
            ->map(fn ($value) => strtolower(trim((string) $value)))
            ->filter()
            ->values();
    }

    private function aiEnabled(): bool
    {
        $setting = SystemSetting::query()->where('key', 'ai_enabled')->value('value');
        if ($setting === null) {
            return true;
        }
        if (is_bool($setting)) {
            return $setting;
        }
        if (is_numeric($setting)) {
            return (bool) $setting;
        }
        if (is_string($setting)) {
            return !in_array(strtolower($setting), ['0', 'false', 'no'], true);
        }
        return true;
    }
}
