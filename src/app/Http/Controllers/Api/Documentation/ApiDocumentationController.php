<?php

namespace App\Http\Controllers\Api\Documentation;

use OpenApi\Annotations as OA;

/**
 * @OA\Info(
 *     version="1.0.0",
 *     title="AGL Infrastructure Admin Platform API",
 *     description="Comprehensive API for managing infrastructure, AI orchestration, and automation workflows",
 *     termsOfService="https://agl.com/terms",
 *     @OA\Contact(
 *         email="admin@agl.com",
 *         name="AGL Infrastructure Team"
 *     ),
 *     @OA\License(
 *         name="MIT",
 *         url="https://opensource.org/licenses/MIT"
 *     )
 * )
 * 
 * @OA\Server(
 *     url=L5_SWAGGER_CONST_HOST,
 *     description="AGL Infrastructure API Server"
 * )
 * 
 * @OA\SecurityScheme(
 *     securityScheme="bearerAuth",
 *     type="http",
 *     scheme="bearer",
 *     bearerFormat="JWT",
 *     description="JWT Authorization header using the Bearer scheme"
 * )
 * 
 * @OA\SecurityScheme(
 *     securityScheme="apiKey",
 *     type="apiKey",
 *     in="header",
 *     name="X-API-Key",
 *     description="API Key Authentication"
 * )
 * 
 * @OA\Tag(
 *     name="Authentication",
 *     description="Authentication and authorization endpoints"
 * )
 * 
 * @OA\Tag(
 *     name="Infrastructure",
 *     description="Infrastructure monitoring and management"
 * )
 * 
 * @OA\Tag(
 *     name="AI Models",
 *     description="AI model orchestration and execution"
 * )
 * 
 * @OA\Tag(
 *     name="N8N Workflows",
 *     description="N8N workflow automation integration"
 * )
 * 
 * @OA\Tag(
 *     name="Servers",
 *     description="Proxmox server management"
 * )
 * 
 * @OA\Tag(
 *     name="Containers",
 *     description="Container and VM management"
 * )
 * 
 * @OA\Tag(
 *     name="Backups",
 *     description="Backup creation and restoration"
 * )
 * 
 * @OA\Tag(
 *     name="Notifications",
 *     description="Multi-channel notification system"
 * )
 * 
 * @OA\Tag(
 *     name="Terraform",
 *     description="Infrastructure as Code management"
 * )
 * 
 * @OA\Tag(
 *     name="Metrics",
 *     description="Real-time metrics and monitoring"
 * )
 * 
 * @OA\Tag(
 *     name="Audit",
 *     description="Audit logs and activity tracking"
 * )
 * 
 * @OA\Tag(
 *     name="API Keys",
 *     description="API key management"
 * )
 * 
 * @OA\Schema(
 *     schema="Error",
 *     type="object",
 *     @OA\Property(property="message", type="string", example="Error message"),
 *     @OA\Property(property="errors", type="object", example={"field": ["validation error"]}),
 *     @OA\Property(property="code", type="integer", example=400)
 * )
 * 
 * @OA\Schema(
 *     schema="Pagination",
 *     type="object",
 *     @OA\Property(property="current_page", type="integer", example=1),
 *     @OA\Property(property="per_page", type="integer", example=15),
 *     @OA\Property(property="total", type="integer", example=100),
 *     @OA\Property(property="last_page", type="integer", example=7)
 * )
 */
class ApiDocumentationController
{
    // This controller serves as the main documentation entry point
}