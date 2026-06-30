<?php

namespace App\Enums\PcGamer;

enum BuildStatus: string
{
    case Draft = 'draft';
    case Quoted = 'quoted';
    case Approved = 'approved';
    case Ordered = 'ordered';
    case Assembly = 'assembly';
    case Completed = 'completed';
    case Cancelled = 'cancelled';
}
