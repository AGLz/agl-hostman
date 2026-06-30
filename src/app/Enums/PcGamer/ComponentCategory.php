<?php

namespace App\Enums\PcGamer;

enum ComponentCategory: string
{
    case Gabinete = 'gabinete';
    case Motherboard = 'motherboard';
    case MemoriaDdr5 = 'memoria_ddr5';
    case Nvme = 'nvme';
    case PlacaVideo = 'placa_video';
    case Processador = 'processador';
    case WaterCooler = 'water_cooler';
    case Fan = 'fan';
    case Fonte = 'fonte';
    case SuporteVga = 'suporte_vga';
}
