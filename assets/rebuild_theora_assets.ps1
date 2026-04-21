# Regenerate Godot-ready Theora (.ogv) — cinematic intro: slow dolly (zoompan), 24fps, graded, film grain.
# intro_cinematic: 1280x720 @ q=9 (~6–8 MB / 10s). Requires ffmpeg + libtheora (winget install Gyan.FFmpeg).
$ErrorActionPreference = "Stop"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $here

# Cinematic intro: large gradient plate + slow zoom-in + teal/warm grade + vignette + unsharp + grain (no baked letterbox — Godot draws scope bars).
$srcIntro = "gradients=s=2560x1440:r=30:d=12:nb_colors=5:c0=0x02060c:c1=0x0c1e35:c2=0x1a4a6e:c3=0xd4a84b:c4=0xf5ecd8:type=circular:speed=0.055:x0=1280:y0=720:x1=1800:y1=400:seed=1948"
$vfIntro = "zoompan=z='min(1+0.11*on/239,1.11)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=24,fps=24,eq=saturation=0.7:contrast=1.2:brightness=-0.09:gamma=1.05,colorbalance=rs=-0.12:gs=0.05:bs=0.1:rm=0.05:gm=-0.03:bm=-0.08:rh=0.1:gh=0.04:bh=-0.14,vignette=angle=PI/2.3,unsharp=5:5:0.5:3:3:0,noise=alls=10:allf=t+u,format=yuv420p"

ffmpeg -y -f lavfi -i $srcIntro -t 10 -vf $vfIntro -frames:v 240 -c:v libtheora -q:v 9 -an "intro_cinematic.ogv"

$vfMenu = "gblur=sigma=0.5,eq=saturation=0.92:brightness=-0.04,vignette=angle=PI/3,noise=alls=2:allf=t+u,format=yuv420p"
$gradMenu = "gradients=s=1920x1080:r=30:d=12:nb_colors=3:c0=0x0e1c2e:c1=0x2a4a6a:c2=0x8b7355:type=spiral:speed=0.04:seed=75"

ffmpeg -y -f lavfi -i $gradMenu -vf $vfMenu -c:v libtheora -q:v 10 -an "menu_ambience.ogv"

$vfSting = "eq=saturation=1.15:contrast=1.1,vignette=angle=PI/5,noise=alls=3:allf=t+u,format=yuv420p,fps=30"
$gradSting = "gradients=s=1920x1080:r=60:d=3:nb_colors=3:c0=0x000000:c1=0xf2c814:c2=0xffffff:type=radial:speed=0.35:x0=960:y0=540:x1=300:y1=540:seed=42"

ffmpeg -y -f lavfi -i $gradSting -vf $vfSting -c:v libtheora -q:v 10 -an "transition_stinger.ogv"

Write-Host "Done: intro_cinematic.ogv (cinematic), menu_ambience.ogv, transition_stinger.ogv"
