<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ApiKey;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use OpenApi\Annotations as OA;

class ApiKeyController extends Controller
{
    /**
     * @OA\Get(
     *     path="/api/api-keys",
     *     tags={"API Keys"},
     *     summary="List API keys",
     *     description="Get list of all API keys for the authenticated user",
     *     operationId="listApiKeys",
     *     security={{"bearerAuth":{}}},
     *     @OA\Response(
     *         response=200,
     *         description="List of API keys",
     *         @OA\JsonContent(
     *             type="array",
     *             @OA\Items(
     *                 @OA\Property(property="id", type="integer", example=1),
     *                 @OA\Property(property="name", type="string", example="Production API Key"),
     *                 @OA\Property(property="key", type="string", example="ak_1234...abcd", description="Partial key for identification"),
     *                 @OA\Property(property="permissions", type="array", @OA\Items(type="string")),
     *                 @OA\Property(property="rate_limit", type="integer", example=60),
     *                 @OA\Property(property="usage_count", type="integer", example=1523),
     *                 @OA\Property(property="last_used_at", type="string", format="date-time"),
     *                 @OA\Property(property="expires_at", type="string", format="date-time"),
     *                 @OA\Property(property="is_active", type="boolean", example=true),
     *                 @OA\Property(property="created_at", type="string", format="date-time")
     *             )
     *         )
     *     )
     * )
     */
    public function index(Request $request)
    {
        $apiKeys = $request->user()->apiKeys()
            ->select(['id', 'name', 'permissions', 'rate_limit', 'usage_count', 'last_used_at', 'expires_at', 'is_active', 'created_at'])
            ->get()
            ->map(function ($key) {
                $key->key = substr($key->key, 0, 8) . '...' . substr($key->key, -4);
                return $key;
            });

        return response()->json($apiKeys);
    }

    /**
     * @OA\Post(
     *     path="/api/api-keys",
     *     tags={"API Keys"},
     *     summary="Create API key",
     *     description="Create a new API key with specified permissions",
     *     operationId="createApiKey",
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"name"},
     *             @OA\Property(property="name", type="string", example="Production API Key"),
     *             @OA\Property(property="permissions", type="array", @OA\Items(type="string"), example={"read:infrastructure", "write:containers"}),
     *             @OA\Property(property="rate_limit", type="integer", example=60, description="Requests per minute"),
     *             @OA\Property(property="expires_in_days", type="integer", example=90, description="Days until expiration")
     *         )
     *     ),
     *     @OA\Response(
     *         response=201,
     *         description="API key created",
     *         @OA\JsonContent(
     *             @OA\Property(property="id", type="integer", example=1),
     *             @OA\Property(property="name", type="string", example="Production API Key"),
     *             @OA\Property(property="key", type="string", example="ak_1234567890abcdefghijklmnopqrstuvwxyz", description="Full key shown only once"),
     *             @OA\Property(property="secret", type="string", example="sk_abcdefghijklmnopqrstuvwxyz1234567890", description="Secret shown only once"),
     *             @OA\Property(property="permissions", type="array", @OA\Items(type="string")),
     *             @OA\Property(property="rate_limit", type="integer", example=60),
     *             @OA\Property(property="expires_at", type="string", format="date-time"),
     *             @OA\Property(property="created_at", type="string", format="date-time")
     *         )
     *     ),
     *     @OA\Response(
     *         response=400,
     *         description="Invalid request",
     *         @OA\JsonContent(ref="#/components/schemas/Error")
     *     )
     * )
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'permissions' => 'array|nullable',
            'permissions.*' => 'string',
            'rate_limit' => 'integer|min:1|max:1000',
            'expires_in_days' => 'integer|min:1|max:365'
        ]);

        $key = 'ak_' . Str::random(40);
        $secret = 'sk_' . Str::random(60);

        $apiKey = $request->user()->apiKeys()->create([
            'name' => $validated['name'],
            'key' => $key,
            'secret' => bcrypt($secret),
            'permissions' => $validated['permissions'] ?? [],
            'rate_limit' => $validated['rate_limit'] ?? 60,
            'expires_at' => isset($validated['expires_in_days']) 
                ? now()->addDays($validated['expires_in_days'])
                : null,
            'is_active' => true
        ]);

        return response()->json([
            'id' => $apiKey->id,
            'name' => $apiKey->name,
            'key' => $key,
            'secret' => $secret,
            'permissions' => $apiKey->permissions,
            'rate_limit' => $apiKey->rate_limit,
            'expires_at' => $apiKey->expires_at,
            'created_at' => $apiKey->created_at,
            'message' => 'Store these credentials securely. The secret will not be shown again.'
        ], 201);
    }

    /**
     * @OA\Delete(
     *     path="/api/api-keys/{id}",
     *     tags={"API Keys"},
     *     summary="Delete API key",
     *     description="Revoke and delete an API key",
     *     operationId="deleteApiKey",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         description="API key ID",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=204,
     *         description="API key deleted"
     *     ),
     *     @OA\Response(
     *         response=404,
     *         description="API key not found",
     *         @OA\JsonContent(ref="#/components/schemas/Error")
     *     )
     * )
     */
    public function destroy(Request $request, $id)
    {
        $apiKey = $request->user()->apiKeys()->findOrFail($id);
        $apiKey->delete();

        return response()->noContent();
    }

    /**
     * @OA\Patch(
     *     path="/api/api-keys/{id}/toggle",
     *     tags={"API Keys"},
     *     summary="Toggle API key status",
     *     description="Enable or disable an API key",
     *     operationId="toggleApiKey",
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         description="API key ID",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="API key status toggled",
     *         @OA\JsonContent(
     *             @OA\Property(property="id", type="integer", example=1),
     *             @OA\Property(property="is_active", type="boolean", example=false),
     *             @OA\Property(property="message", type="string", example="API key disabled")
     *         )
     *     ),
     *     @OA\Response(
     *         response=404,
     *         description="API key not found"
     *     )
     * )
     */
    public function toggle(Request $request, $id)
    {
        $apiKey = $request->user()->apiKeys()->findOrFail($id);
        $apiKey->is_active = !$apiKey->is_active;
        $apiKey->save();

        return response()->json([
            'id' => $apiKey->id,
            'is_active' => $apiKey->is_active,
            'message' => $apiKey->is_active ? 'API key enabled' : 'API key disabled'
        ]);
    }
}