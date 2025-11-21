<?php

namespace App\Http\Middleware;

use App\Models\AuditLog as AuditLogModel;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class AuditLog
{
    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Generate request ID if not present
        if (!$request->attributes->has('request_id')) {
            $request->attributes->set('request_id', Str::uuid()->toString());
        }
        
        // Process the request
        $response = $next($request);
        
        // Log the action if it's a write operation
        if (in_array($request->method(), ['POST', 'PUT', 'PATCH', 'DELETE'])) {
            $this->logAction($request, $response);
        }
        
        return $response;
    }
    
    /**
     * Log the action
     */
    protected function logAction(Request $request, Response $response): void
    {
        try {
            $user = $request->user();
            $apiKey = $request->attributes->get('api_key');
            
            $log = [
                'user_id' => $user?->id,
                'api_key_id' => $apiKey?->id,
                'action' => $this->getAction($request),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'request_id' => $request->attributes->get('request_id'),
                'session_id' => $request->session()?->getId(),
                'metadata' => [
                    'method' => $request->method(),
                    'url' => $request->fullUrl(),
                    'status' => $response->getStatusCode(),
                    'route' => $request->route()?->getName(),
                    'parameters' => $this->sanitizeParameters($request->all()),
                ],
            ];
            
            // Try to detect model changes
            if ($request->route()) {
                $this->detectModelChanges($request, $log);
            }
            
            AuditLogModel::create($log);
            
        } catch (\Exception $e) {
            // Don't fail the request if logging fails
            \Log::error('Audit logging failed', [
                'error' => $e->getMessage(),
                'request' => $request->fullUrl(),
            ]);
        }
    }
    
    /**
     * Get action name from request
     */
    protected function getAction(Request $request): string
    {
        $route = $request->route();
        
        if ($route && $route->getName()) {
            return $route->getName();
        }
        
        // Build action from method and path
        $path = str_replace('/api/', '', $request->path());
        $method = strtolower($request->method());
        
        return "{$method}:{$path}";
    }
    
    /**
     * Detect model changes
     */
    protected function detectModelChanges(Request $request, array &$log): void
    {
        $route = $request->route();
        $parameters = $route->parameters();
        
        // Try to detect the model from route parameters
        foreach ($parameters as $key => $value) {
            if (is_object($value) && method_exists($value, 'getMorphClass')) {
                $log['model_type'] = $value->getMorphClass();
                $log['model_id'] = $value->getKey();
                
                // If it's an update, try to get old values
                if (in_array($request->method(), ['PUT', 'PATCH'])) {
                    $log['old_values'] = $this->getOldValues($value);
                    $log['new_values'] = $this->getNewValues($value, $request->all());
                }
                
                break;
            }
        }
    }
    
    /**
     * Get old values from model
     */
    protected function getOldValues($model): array
    {
        if (method_exists($model, 'getOriginal')) {
            $original = $model->getOriginal();
            
            // Remove sensitive fields
            unset($original['password'], $original['remember_token']);
            
            return $original;
        }
        
        return [];
    }
    
    /**
     * Get new values
     */
    protected function getNewValues($model, array $input): array
    {
        $fillable = $model->getFillable();
        
        $newValues = array_intersect_key($input, array_flip($fillable));
        
        // Remove sensitive fields
        unset($newValues['password'], $newValues['password_confirmation']);
        
        return $newValues;
    }
    
    /**
     * Sanitize parameters for logging
     */
    protected function sanitizeParameters(array $parameters): array
    {
        $sensitive = [
            'password',
            'password_confirmation',
            'token',
            'secret',
            'api_key',
            'private_key',
            'credit_card',
        ];
        
        foreach ($sensitive as $field) {
            if (isset($parameters[$field])) {
                $parameters[$field] = '***REDACTED***';
            }
        }
        
        return $parameters;
    }
}