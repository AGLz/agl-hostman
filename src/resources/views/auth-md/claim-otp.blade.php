<!DOCTYPE html>
<html lang="pt">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Verificação — {{ $appName }}</title>
    <style>
        body {
            font-family: system-ui, sans-serif;
            max-width: 28rem;
            margin: 3rem auto;
            padding: 0 1rem;
            color: #1a1a1a;
        }

        h1 {
            font-size: 1.25rem;
        }

        p {
            line-height: 1.5;
            color: #444;
        }
    </style>
</head>

<body>
    <h1>{{ $appName }}</h1>
    <p>Foi enviado um código de 6 dígitos para <strong>{{ $email }}</strong>. Leia o código no email e indique-o ao agente para concluir o registo (auth.md).</p>
</body>

</html>