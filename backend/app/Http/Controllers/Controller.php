<?php

namespace App\Http\Controllers;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Collection;

abstract class Controller
{
    protected function paginatedResponse(LengthAwarePaginator $paginator, ?string $resourceClass = null): JsonResponse
    {
        $items = collect($paginator->items());
        $data = $this->transformCollection($items, $resourceClass);

        return response()->json([
            'data' => $data,
            'meta' => $this->paginationMeta($paginator),
        ]);
    }

    protected function collectionResponse(Collection $items, ?string $resourceClass = null): array
    {
        return [
            'data' => $this->transformCollection($items, $resourceClass),
            'meta' => [
                'total' => $items->count(),
            ],
        ];
    }

    protected function paginationMeta(LengthAwarePaginator $paginator): array
    {
        return [
            'page' => $paginator->currentPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
            'last_page' => $paginator->lastPage(),
        ];
    }

    private function transformCollection(Collection $items, ?string $resourceClass): array
    {
        if ($resourceClass && is_subclass_of($resourceClass, JsonResource::class)) {
            return $resourceClass::collection($items)->resolve();
        }

        return $items->values()->all();
    }
}
