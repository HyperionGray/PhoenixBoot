#!/usr/bin/env bash
# Description: Creates the initial directory structure for the project.

set -euo pipefail

# Create component directories
mkdir -p components/{core,secure,workflows,maint}
mkdir -p components/core/{build,scripts}
mkdir -p components/secure/{include,src,build,bin,scripts}
mkdir -p components/workflows/{include,src,build,bin,scripts}
mkdir -p components/maint/{include,src,build,bin,scripts}

# Core component links existing production sources
ln -snf ../../staging/src components/core/src
ln -snf ../../staging/include components/core/include
ln -snf ../../staging/boot components/core/bin

# Shared includes
mkdir -p includes/lib
ln -snf ../components/core/include includes/core
ln -snf ../components/secure/include includes/secure
ln -snf ../components/workflows/include includes/workflows
ln -snf ../components/maint/include includes/maint

# Component Makefiles
for component in core secure workflows maint; do
    ln -snf ../../Makefile "components/$component/Makefile"
done

# Component Pfyfiles
touch components/core/Pfyfile.pf components/secure/Pfyfile.pf components/workflows/Pfyfile.pf components/maint/Pfyfile.pf

# Create staging directories
mkdir -p staging/{src,include,boot,drivers,platform,tests,tools}

# Create dev directories
mkdir -p dev/{boot,bringup,tools}

# Create WIP directories
mkdir -p wip/universal-bios

# Create demo directory
mkdir -p demo

# Create output directories
mkdir -p out/{staging,esp,qemu,lint}

# Keep directories with .gitkeep
for dir in components/secure/{include,src,build,bin,scripts} components/workflows/{include,src,build,bin,scripts} components/maint/{include,src,build,bin,scripts} components/core/{build,scripts} staging/{src,include,boot,drivers,platform,tests,tools} dev/{boot,bringup,tools} wip/universal-bios demo out/{staging,esp,qemu,lint}; do
    touch "$dir/.gitkeep"
done

echo "☠ Component-first project structure created"
