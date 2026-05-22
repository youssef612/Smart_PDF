f = open('app/Http/Controllers/FilesController.php', 'r')
content = f.read()
f.close()

old = (
    "$part = preg_replace('/[x{4E00}-x{9FFF}x{3040}-x{30FF}x{AC00}-x{D7AF}]+/u', '', $part);\n"
    "                $part = preg_replace('/\\s{2,}/', ' ', $part);\n"
    "                $part = preg_replace('/s{2,}/', ' ', $part);"
)

new = (
    r"$part = preg_replace('/[\x{4E00}-\x{9FFF}\x{3040}-\x{30FF}\x{AC00}-\x{D7AF}]+/u', '', $part);" + "\n"
    r"                $part = trim(preg_replace('/\s+/', ' ', $part));"
)

if old in content:
    content = content.replace(old, new)
    f = open('app/Http/Controllers/FilesController.php', 'w')
    f.write(content)
    f.close()
    print('Done - replaced successfully')
else:
    print('NOT FOUND - printing actual lines 783-785:')
    for i, line in enumerate(content.split('\n')[782:786], 783):
        print(f'{i}: {repr(line)}')
