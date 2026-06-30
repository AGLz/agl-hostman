<?php

namespace App\Enums\PcGamer;

enum OfferStatus: string
{
    case New = 'new';
    case Active = 'active';
    case PriceChanged = 'price_changed';
    case Unavailable = 'unavailable';
    case NeedsManual = 'needs_manual';
    case Expired = 'expired';
}
