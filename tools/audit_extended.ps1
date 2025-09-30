$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mods = @(
    @{ Name = 'Morgenrote'; Path = Join-Path $root 'Morgenrote' },
    @{ Name = 'TGR';        Path = Join-Path $root 'The great revision' }
)

$scanRoots = @(
    'common',
    'events',
    'gfx',
    'gui',
    'localization\english'
)

function Get-TopLevelIds {
    param(
        [Parameter(Mandatory=$true)]
        [string] $FilePath
    )
    $ids = @()
    if (-not (Test-Path -LiteralPath $FilePath)) { return $ids }
    $text = Get-Content -LiteralPath $FilePath -Raw
    $lines = $text -split "\r?\n"
    $depth = 0
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match '^(#|//)') { continue }
        if (($depth -eq 0) -and ($t -match '^\s*([A-Za-z0-9_.:-]+)\s*=\s*\{')) {
            $ids += $Matches[1]
        }
        $openCount  = ([regex]::Matches($t, '\{')).Count
        $closeCount = ([regex]::Matches($t, '\}')).Count
        $depth += ($openCount - $closeCount)
        if ($depth -lt 0) { $depth = 0 }
    }
    return $ids
}

function Get-TopLevelKeys {
    param(
        [Parameter(Mandatory=$true)]
        [string] $FilePath
    )
    $keys = @()
    if (-not (Test-Path -LiteralPath $FilePath)) { return $keys }
    $text = Get-Content -LiteralPath $FilePath -Raw
    $lines = $text -split "\r?\n"
    $depth = 0
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match '^(#|//)') { continue }
        if ($depth -eq 0 -and $t -match '^\s*([A-Za-z0-9_.:-]+)\s*=') {
            $keys += $Matches[1]
        }
        $openCount  = ([regex]::Matches($t, '\{')).Count
        $closeCount = ([regex]::Matches($t, '\}')).Count
        $depth += ($openCount - $closeCount)
        if ($depth -lt 0) { $depth = 0 }
    }
    return $keys
}

function Get-TopLevelBlocks {
    param(
        [Parameter(Mandatory=$true)]
        [string] $FilePath
    )
    $map = @{}
    if (-not (Test-Path -LiteralPath $FilePath)) { return $map }
    $text = Get-Content -LiteralPath $FilePath -Raw
    $lines = $text -split "\r?\n"
    $depth = 0
    $currentName = $null
    $currentBuf = New-Object System.Text.StringBuilder
    foreach ($line in $lines) {
        $t = $line
        $trim = $t.Trim()
        if ($trim -match '^(#|//)') { continue }
        if ($depth -eq 0 -and $trim -match '^\s*([A-Za-z0-9_.:-]+)\s*=\s*\{') {
            $currentName = $Matches[1]
        }
        $openCount  = ([regex]::Matches($t, '\{')).Count
        $closeCount = ([regex]::Matches($t, '\}')).Count
        if ($depth -ge 1 -or $openCount -gt 0) { [void]$currentBuf.AppendLine($t) }
        $depth += ($openCount - $closeCount)
        if ($depth -lt 0) { $depth = 0 }
        if ($depth -eq 0 -and $currentName) {
            $content = $currentBuf.ToString()
            $map[$currentName] = $content
            $currentName = $null
            $currentBuf.Clear() | Out-Null
        }
    }
    return $map
}

function Get-LocKeys {
    param(
        [Parameter(Mandatory=$true)]
        [string] $FilePath
    )
    $result = @()
    if (-not (Test-Path -LiteralPath $FilePath)) { return $result }
    $text = Get-Content -LiteralPath $FilePath -Raw
    $lines = $text -split "\r?\n"
    $inHeader = $false
    foreach ($line in $lines) {
        $l = $line.Trim()
        if (-not $inHeader) {
            if ($l -match '^l_english\s*:\s*$') { $inHeader = $true }
            continue
        }
        if ($l -match '^([A-Za-z0-9_.:-]+)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2]
            # strip inline comment
            $val = ($val -split '\s+#',2)[0].Trim()
            $result += ,@($key,$val)
        }
    }
    return $result
}

function Find-ElementLineNumber {
    param(
        [Parameter(Mandatory=$true)]
        [string] $FilePath,
        [Parameter(Mandatory=$true)]
        [string] $ElementId,
        [Parameter(Mandatory=$false)]
        [string] $ElementType = "id"
    )
    if (-not (Test-Path -LiteralPath $FilePath)) { return $null }
    
    $text = Get-Content -LiteralPath $FilePath -Raw
    $lines = $text -split "\r?\n"
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -match '^(#|//)') { continue }
        
        switch ($ElementType) {
            "id" { 
                if ($line -match '^\s*' + [regex]::Escape($ElementId) + '\s*=\s*\{') {
                    return ($i + 1)
                }
            }
            "key" { 
                if ($line -match '^\s*' + [regex]::Escape($ElementId) + '\s*:\s*') {
                    return ($i + 1)
                }
            }
            "event" {
                if ($line -match '^\s*id\s*=\s*' + [regex]::Escape($ElementId)) {
                    return ($i + 1)
                }
            }
            "gui" {
                if ($line -match '^\s*name\s*=\s*"?' + [regex]::Escape($ElementId) + '"?') {
                    return ($i + 1)
                }
            }
            "gfx" {
                if ($line -match '^\s*name\s*=\s*"?' + [regex]::Escape($ElementId) + '"?') {
                    return ($i + 1)
                }
            }
            "on_action" {
                if ($line -match '^\s*' + [regex]::Escape($ElementId) + '\s*=\s*\{') {
                    return ($i + 1)
                }
            }
            "script_value" {
                if ($line -match '^\s*' + [regex]::Escape($ElementId) + '\s*=\s*') {
                    return ($i + 1)
                }
            }
            "static_modifier" {
                if ($line -match '^\s*' + [regex]::Escape($ElementId) + '\s*=\s*\{') {
                    return ($i + 1)
                }
            }
        }
    }
    return $null
}

function Get-ShortPath {
    param(
        [Parameter(Mandatory=$true)]
        [string] $FullPath,
        [Parameter(Mandatory=$true)]
        [string] $RootPath
    )
    return $FullPath -replace [regex]::Escape($RootPath), '~'
}

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

$compatchRoot = Join-Path $root 'Morgenrote + TGR compatch'

# Indexes
$pathConflicts = @() # list of PSCustomObject { RelPath, Category }
$pathIndexMap = @{} # relPath(lower) -> set of mods
$idIndex = @{}      # key: CategoryFolder::Id -> { Mods: set, Files: map mod->list relpaths }
$locIndex = @{}     # key: key -> { Mods: set, Values: map mod->value, Files: map mod->list relpaths }
$eventIndex = @{}   # key: eventId -> { Mods:set, Files: map mod->list relpaths }
$guiNameIndex = @{} # key: guiName -> { Mods:set, Files: map mod->list relpaths }
$gfxSpriteIndex = @{} # key: spriteName -> { Mods:set, Texture: map mod->texture, Files: map mod->list relpaths }
$onActionIndex = @{} # key: on_action_name -> { Mods:set, Hash: map mod->hash, Files: map mod->list relpaths }
$scriptValuesIndex = @{} # key: valueName -> { Mods:set, Val: map mod->scalar, Files: map mod->list relpaths }
$staticModifiersIndex = @{} # key: modifierName -> { Mods:set, Hash: map mod->hash, Files: map mod->list relpaths }

# Collect data
foreach ($m in $mods) {
    foreach ($cat in $scanRoots) {
        $base = Join-Path $m.Path $cat
        if (-not (Test-Path -LiteralPath $base)) { continue }
        $files = Get-ChildItem -LiteralPath $base -Recurse -File
        foreach ($f in $files) {
            $rel = ($f.FullName).Substring($m.Path.Length).TrimStart('\\')
            # Track path presence to detect overwrites
            $pathKey = $rel.ToLowerInvariant()
            if (-not $pathIndexMap.ContainsKey($pathKey)) { $pathIndexMap[$pathKey] = @{} }
            $pathIndexMap[$pathKey][$m.Name] = $true

            $ext = $f.Extension.ToLowerInvariant()
            $isText = $ext -in @('.txt','.gui','.asset','.mesh','.yml','.gfx')

            # IDs/keys in text-like files (not localization yml)
            if ($isText -and -not ($rel -like 'localization*')) {
                $ids = Get-TopLevelIds -FilePath $f.FullName
                $keys = Get-TopLevelKeys -FilePath $f.FullName
                $folder = ($rel -split '\\',2)[0]
                $all = ($ids + $keys) | Select-Object -Unique
                foreach ($id in $all) {
                    $key = "$folder::$id"
                    if (-not $idIndex.ContainsKey($key)) {
                        $idIndex[$key] = @{ Mods = @{$m.Name=$true}; Files = @{$m.Name=@($rel)} }
                    } else {
                        $idIndex[$key].Mods[$m.Name] = $true
                        if (-not $idIndex[$key].Files.ContainsKey($m.Name)) { $idIndex[$key].Files[$m.Name]=@() }
                        $idIndex[$key].Files[$m.Name] += $rel
                    }
                }
            }

            # Localization keys
            if ($rel -like 'localization\\english*' -and $ext -eq '.yml') {
                $pairs = Get-LocKeys -FilePath $f.FullName
                foreach ($pair in $pairs) {
                    $key = $pair[0]
                    $val = $pair[1]
                    if (-not $locIndex.ContainsKey($key)) {
                        $locIndex[$key] = @{ Mods=@{$m.Name=$true}; Values=@{$m.Name=$val}; Files=@{$m.Name=@($rel)} }
                    } else {
                        $locIndex[$key].Mods[$m.Name] = $true
                        $locIndex[$key].Values[$m.Name] = $val
                        if (-not $locIndex[$key].Files.ContainsKey($m.Name)) { $locIndex[$key].Files[$m.Name]=@() }
                        $locIndex[$key].Files[$m.Name] += $rel
                    }
                }
            }

            # Events
            if ($rel -like 'events*' -and $isText) {
                $text = Get-Content -LiteralPath $f.FullName -Raw
                $ns = ''
                $mNs = [regex]::Match($text, '(?m)^\s*namespace\s*=\s*([A-Za-z0-9_\.:\-]+)')
                if ($mNs.Success) { $ns = $mNs.Groups[1].Value }
                foreach ($mEvent in [regex]::Matches($text, '(?ms)^\s*event\s*=\s*\{.*?^\s*\}', 'Multiline')) {
                    $block = $mEvent.Value
                    $mId = [regex]::Match($block, '(?m)^\s*id\s*=\s*([A-Za-z0-9_\.:\-]+)')
                    if ($mId.Success) {
                        $rawId = $mId.Groups[1].Value
                        $eid = if ($rawId -like '*.*') { $rawId } elseif ($ns) { "$ns.$rawId" } else { $rawId }
                        if (-not $eventIndex.ContainsKey($eid)) {
                            $eventIndex[$eid] = @{ Mods=@{$m.Name=$true}; Files=@{$m.Name=@($rel)} }
                        } else {
                            $eventIndex[$eid].Mods[$m.Name] = $true
                            if (-not $eventIndex[$eid].Files.ContainsKey($m.Name)) { $eventIndex[$eid].Files[$m.Name]=@() }
                            $eventIndex[$eid].Files[$m.Name] += $rel
                        }
                    }
                }
            }

            # GUI names
            if ($rel -like 'gui*' -and $ext -eq '.gui') {
                $text = Get-Content -LiteralPath $f.FullName -Raw
                foreach ($mName in [regex]::Matches($text, '(?m)^\s*name\s*=\s*"?([A-Za-z0-9_\.:\-]+)"?')) {
                    $gname = $mName.Groups[1].Value
                    if (-not $guiNameIndex.ContainsKey($gname)) {
                        $guiNameIndex[$gname] = @{ Mods=@{$m.Name=$true}; Files=@{$m.Name=@($rel)} }
                    } else {
                        $guiNameIndex[$gname].Mods[$m.Name] = $true
                        if (-not $guiNameIndex[$gname].Files.ContainsKey($m.Name)) { $guiNameIndex[$gname].Files[$m.Name]=@() }
                        $guiNameIndex[$gname].Files[$m.Name] += $rel
                    }
                }
            }

            # GFX sprites
            if ($rel -like 'gfx*' -and $ext -eq '.gfx') {
                $text = Get-Content -LiteralPath $f.FullName -Raw
                foreach ($mBlock in [regex]::Matches($text, '(?ms)^(\s*(spriteType|spriteFont|textSpriteType|iconType)\s*=\s*\{).*?^\s*\}', 'Multiline')) {
                    $block = $mBlock.Value
                    $mN = [regex]::Match($block, '(?m)\bname\s*=\s*"?([^"\r\n}]+)')
                    if (-not $mN.Success) { continue }
                    $sname = $mN.Groups[1].Value.Trim()
                    $mT = [regex]::Match($block, '(?m)\btexturefile\s*=\s*"?([^"\r\n}]+)')
                    $tex = if ($mT.Success) { $mT.Groups[1].Value.Trim() } else { '' }
                    if (-not $gfxSpriteIndex.ContainsKey($sname)) {
                        $gfxSpriteIndex[$sname] = @{ Mods=@{$m.Name=$true}; Texture=@{$m.Name=$tex}; Files=@{$m.Name=@($rel)} }
                    } else {
                        $gfxSpriteIndex[$sname].Mods[$m.Name] = $true
                        $gfxSpriteIndex[$sname].Texture[$m.Name] = $tex
                        if (-not $gfxSpriteIndex[$sname].Files.ContainsKey($m.Name)) { $gfxSpriteIndex[$sname].Files[$m.Name]=@() }
                        $gfxSpriteIndex[$sname].Files[$m.Name] += $rel
                    }
                }
            }

            # on_actions nodes
            if ($rel -like 'common\on_actions*') {
                $text = Get-Content -LiteralPath $f.FullName -Raw
                foreach ($mBlock in [regex]::Matches($text, '(?ms)^\s*on_actions\s*=\s*\{(.*?)^\s*\}', 'Multiline')) {
                    $inner = $mBlock.Groups[1].Value
                    foreach ($mEntry in [regex]::Matches($inner, '(?ms)^\s*([A-Za-z0-9_\.:\-]+)\s*=\s*\{(.*?)^\s*\}', 'Multiline')) {
                        $name = $mEntry.Groups[1].Value
                        $content = ($mEntry.Groups[2].Value -replace '\s+', ' ').Trim()
                        $sha1 = New-Object -TypeName System.Security.Cryptography.SHA1Managed
                        $hash = [BitConverter]::ToString($sha1.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))
                        if (-not $onActionIndex.ContainsKey($name)) {
                            $onActionIndex[$name] = @{ Mods=@{$m.Name=$true}; Hash=@{$m.Name=$hash}; Files=@{$m.Name=@($rel)} }
                        } else {
                            $onActionIndex[$name].Mods[$m.Name] = $true
                            $onActionIndex[$name].Hash[$m.Name] = $hash
                            if (-not $onActionIndex[$name].Files.ContainsKey($m.Name)) { $onActionIndex[$name].Files[$m.Name]=@() }
                            $onActionIndex[$name].Files[$m.Name] += $rel
                        }
                    }
                }
            }

            # script_values scalar
            if ($rel -like 'common\script_values*') {
                $text = Get-Content -LiteralPath $f.FullName -Raw
                foreach ($mAssign in [regex]::Matches($text, '(?m)^\s*([A-Za-z0-9_\.:\-]+)\s*=\s*([^\{][^#\r\n]*)')) {
                    $name = $mAssign.Groups[1].Value.Trim()
                    $val = $mAssign.Groups[2].Value.Trim()
                    if (-not $scriptValuesIndex.ContainsKey($name)) {
                        $scriptValuesIndex[$name] = @{ Mods=@{$m.Name=$true}; Val=@{$m.Name=$val}; Files=@{$m.Name=@($rel)} }
                    } else {
                        $scriptValuesIndex[$name].Mods[$m.Name] = $true
                        $scriptValuesIndex[$name].Val[$m.Name] = $val
                        if (-not $scriptValuesIndex[$name].Files.ContainsKey($m.Name)) { $scriptValuesIndex[$name].Files[$m.Name]=@() }
                        $scriptValuesIndex[$name].Files[$m.Name] += $rel
                    }
                }
            }

            # static_modifiers content hash
            if ($rel -like 'common\static_modifiers*') {
                $blocks = Get-TopLevelBlocks -FilePath $f.FullName
                foreach ($kvp in $blocks.GetEnumerator()) {
                    $name = $kvp.Key
                    $content = ($kvp.Value -replace '\s+', ' ').Trim()
                    $sha1 = New-Object -TypeName System.Security.Cryptography.SHA1Managed
                    $hash = [BitConverter]::ToString($sha1.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))
                    if (-not $staticModifiersIndex.ContainsKey($name)) {
                        $staticModifiersIndex[$name] = @{ Mods=@{$m.Name=$true}; Hash=@{$m.Name=$hash}; Files=@{$m.Name=@($rel)} }
                    } else {
                        $staticModifiersIndex[$name].Mods[$m.Name] = $true
                        $staticModifiersIndex[$name].Hash[$m.Name] = $hash
                        if (-not $staticModifiersIndex[$name].Files.ContainsKey($m.Name)) { $staticModifiersIndex[$name].Files[$m.Name]=@() }
                        $staticModifiersIndex[$name].Files[$m.Name] += $rel
                    }
                }
            }
        }
    }
}

# Detect path conflicts (overwrites)
foreach ($kv in $pathIndexMap.GetEnumerator()) {
    if ($kv.Value.Keys.Count -ge 2) {
        $pathConflicts += [PSCustomObject]@{ RelPath = $kv.Key; Category = ($kv.Key.Split('\\')[0]) }
    }
}

$outCommon = Join-Path $compatchRoot 'common'
$outEvents = Join-Path $compatchRoot 'events'
$outGfx    = Join-Path $compatchRoot 'gfx'
$outGui    = Join-Path $compatchRoot 'gui'
$outLocEn  = Join-Path $compatchRoot 'localization\english'

Ensure-Dir $outCommon; Ensure-Dir $outEvents; Ensure-Dir $outGfx; Ensure-Dir $outGui; Ensure-Dir $outLocEn

function Append-Lines {
    param([string]$Path,[string[]]$Lines)
    $dir = Split-Path -Parent $Path
    Ensure-Dir $dir
    Add-Content -LiteralPath $Path -Value ($Lines -join "`n")
}

# Write path conflict markers
foreach ($c in $pathConflicts) {
    $rel = $c.RelPath
    $ext = [System.IO.Path]::GetExtension($rel).ToLowerInvariant()
    $dest = Join-Path $compatchRoot $rel
    $isText = $ext -in @('.txt','.gui','.asset','.mesh','.yml')
    if ($isText) {
        Append-Lines -Path $dest -Lines @(
            ('FILE_CONFLICT same_path = ' + $rel),
            ('# exists_in_Morgenrote = ' + $rel),
            ('# exists_in_TGR = ' + $rel),
            ''
        )
    }
    else {
        $dir = Join-Path $compatchRoot ([System.IO.Path]::GetDirectoryName($rel))
        $name = [System.IO.Path]::GetFileName($rel)
        $marker = Join-Path $dir ('CONFLICT_' + $name + '.txt')
        Append-Lines -Path $marker -Lines @(
            ('FILE_CONFLICT same_path = ' + $rel),
            ('# exists_in_Morgenrote = ' + $rel),
            ('# exists_in_TGR = ' + $rel),
            ''
        )
    }
}

# Write ID conflict markers (top-level ids across folders)
$idConflicts = $idIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $idConflicts) {
    $parts = $c.Key -split '::',2
    $folder = $parts[0]
    $id = $parts[1]
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $destDir = Join-Path $compatchRoot (Join-Path $folder '')
    Ensure-Dir $destDir
    $dest = Join-Path $destDir $destFileName

    # Try to capture header lines from source files with full paths and line numbers
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $id -ElementType "id"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $id -ElementType "id"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ($id + ' = ???'),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write localization key conflict markers (only if texts differ)
$locConflicts = $locIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 -and ($_.Value.Values['Morgenrote'] -ne $_.Value.Values['TGR']) }
foreach ($c in $locConflicts) {
    $key = $c.Key
    # choose a destination file name
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts_l_english.yml' }
    $dest = Join-Path $outLocEn $destFileName

    $mrVal = if ($c.Value.Values.ContainsKey('Morgenrote')) { $c.Value.Values['Morgenrote'] } else { '' }
    $tgrVal = if ($c.Value.Values.ContainsKey('TGR')) { $c.Value.Values['TGR'] } else { '' }

    # Get full paths and line numbers for localization keys
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $key -ElementType "key"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $key -ElementType "key"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ($key + ' = ???'),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write event conflict markers
$eventConflicts = $eventIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $eventConflicts) {
    $eventId = $c.Key
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $dest = Join-Path $outEvents $destFileName

    # Get full paths and line numbers for events
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $eventId -ElementType "event"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $eventId -ElementType "event"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ('event = ??? # ' + $eventId),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write GUI name conflict markers
$guiConflicts = $guiNameIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $guiConflicts) {
    $guiName = $c.Key
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $dest = Join-Path $outGui $destFileName

    # Get full paths and line numbers for GUI names
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $guiName -ElementType "gui"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $guiName -ElementType "gui"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ('name = ??? # ' + $guiName),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write GFX sprite conflict markers
$gfxConflicts = $gfxSpriteIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $gfxConflicts) {
    $spriteName = $c.Key
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $dest = Join-Path $outGfx $destFileName

    # Get full paths and line numbers for GFX sprites
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $spriteName -ElementType "gfx"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $spriteName -ElementType "gfx"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ('name = ??? # ' + $spriteName),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write on_action conflict markers
$onActionConflicts = $onActionIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $onActionConflicts) {
    $actionName = $c.Key
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $dest = Join-Path $outCommon $destFileName

    # Get full paths and line numbers for on_actions
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $actionName -ElementType "on_action"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $actionName -ElementType "on_action"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ($actionName + ' = ???'),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write script_values conflict markers
$scriptValueConflicts = $scriptValuesIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $scriptValueConflicts) {
    $valueName = $c.Key
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $dest = Join-Path $outCommon $destFileName

    # Get full paths and line numbers for script_values
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $valueName -ElementType "script_value"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $valueName -ElementType "script_value"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ($valueName + ' = ???'),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Write static_modifiers conflict markers
$staticModConflicts = $staticModifiersIndex.GetEnumerator() | Where-Object { $_.Value.Mods.Keys.Count -ge 2 }
foreach ($c in $staticModConflicts) {
    $modifierName = $c.Key
    $mrRel = $c.Value.Files['Morgenrote'] | Select-Object -First 1
    $tgrRel = $c.Value.Files['TGR'] | Select-Object -First 1
    $destFileName = if ($mrRel) { Split-Path $mrRel -Leaf } elseif ($tgrRel) { Split-Path $tgrRel -Leaf } else { 'conflicts.txt' }
    $dest = Join-Path $outCommon $destFileName

    # Get full paths and line numbers for static_modifiers
    $mrInfo = ''; if ($mrRel) { 
        $mrPath = Join-Path (Join-Path $root 'Morgenrote') $mrRel
        if (Test-Path -LiteralPath $mrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $mrPath -ElementId $modifierName -ElementType "static_modifier"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $mrPath -RootPath $root
                $mrInfo = $shortPath
            }
        }
    }
    $tgrInfo = ''; if ($tgrRel) { 
        $tgrPath = Join-Path (Join-Path $root 'The great revision') $tgrRel
        if (Test-Path -LiteralPath $tgrPath) { 
            $lineNum = Find-ElementLineNumber -FilePath $tgrPath -ElementId $modifierName -ElementType "static_modifier"
            if ($lineNum) {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = "$shortPath : $lineNum"
            } else {
                $shortPath = Get-ShortPath -FullPath $tgrPath -RootPath $root
                $tgrInfo = $shortPath
            }
        }
    }

    Append-Lines -Path $dest -Lines @(
        ($modifierName + ' = ???'),
        ('# variant_from_Morgenrote = ' + $mrInfo),
        ('# variant_from_TGR = ' + $tgrInfo),
        ''
    )
}

# Summaries
$sumPath = $pathConflicts | Group-Object { ($_.RelPath -split '\\')[0] } | ForEach-Object { [PSCustomObject]@{ Category=$_.Name; Count=$_.Count } } | Sort-Object Category
$sumIds  = $idConflicts  | Group-Object { ($_.Key -split '::',2)[0] } | ForEach-Object { [PSCustomObject]@{ Category=$_.Name; Count=$_.Count } } | Sort-Object Category
$sumLoc  = [PSCustomObject]@{ Category = 'localization/english'; Count = ($locConflicts.Count) }

Write-Output 'Path overwrite conflicts by category:'
$sumPath | Format-Table -AutoSize | Out-String | Write-Output
Write-Output 'ID collisions by folder:'
$sumIds | Format-Table -AutoSize | Out-String | Write-Output
Write-Output 'Localization key collisions (different texts):'
$sumLoc | Format-Table -AutoSize | Out-String | Write-Output

Write-Output ("Totals -> Paths: {0}, IDs: {1}, Loc keys: {2}, Events: {3}, GUI names: {4}, GFX sprites: {5}, on_actions: {6}, script_values: {7}, static_modifiers: {8}" -f ($pathConflicts.Count), ($idConflicts.Count), ($locConflicts.Count), (($eventConflicts | Measure-Object).Count), (($guiConflicts | Measure-Object).Count), (($gfxConflicts | Measure-Object).Count), (($onActionConflicts | Measure-Object).Count), (($scriptValueConflicts | Measure-Object).Count), (($staticModConflicts | Measure-Object).Count))


