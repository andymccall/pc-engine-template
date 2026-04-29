# ---------------------------------------------------------------------------
# PC Engine / TurboGrafx-16 Template - Master Makefile
# ---------------------------------------------------------------------------
# Single-platform template for the PC Engine (HuC6280). Built with PCEAS,
# the assembler shipped with HuC (https://github.com/pce-devel/huc).
# Output is a HuCard ROM (.pce) playable on Geargrafx, Mesen2, Mednafen,
# Ootake, or real hardware via a flash cart.
#
# Structure mirrors the multi-platform layout from from-the-dead so a
# second platform can be added later under src/<plat>/ with its own build
# target without disturbing this one.
# ---------------------------------------------------------------------------

NAME       = hello

# --- Tools -----------------------------------------------------------------
PCEAS      = pceas
GEARGRAFX  = geargrafx

# HuC install root - derived from where pceas lives so the template works
# regardless of where the user has unpacked HuC. Override on the command
# line if pceas isn't on PATH yet:  make HUC_HOME=/path/to/huc build-pce
HUC_HOME  ?= $(realpath $(dir $(shell command -v $(PCEAS)))/..)

# --- Directories -----------------------------------------------------------
SRCDIR     = src
BUILDDIR   = build
ASSETDIR   = assets
SCRIPTDIR  = scripts
RELEASEDIR = release

# Search paths for PCEAS includes/incbins. Set as PCE_INCLUDE in the
# environment when invoking pceas (the assembler reads it natively).
#
#   src/pce/system     project's own equates + future HAL extensions
#   build/pce          generated assets (pcxtool output, etc.) when added
#   elmer/include      "CORE(not TM)" library (bare-startup, vdc, font, ...)
#   elmer/font         8x8/8x12/8x16 font .dat files used by the example
#   hucc include       pceas.inc + pcengine.inc hardware equates
PCE_INCLUDE_DIRS = $(SRCDIR)/pce/system \
                   $(BUILDDIR)/pce \
                   $(HUC_HOME)/examples/asm/elmer/include \
                   $(HUC_HOME)/examples/asm/elmer/font \
                   $(HUC_HOME)/include/hucc

# Colon-joined for export. PCEAS reads PCE_INCLUDE the same way Unix tools
# read PATH (':' on POSIX, ';' on native Windows CMD - we only target POSIX
# here; Windows users running under MSYS2/Cygwin behave like POSIX).
PCE_INCLUDE := $(subst $(eval) ,:,$(PCE_INCLUDE_DIRS))
export PCE_INCLUDE

# --- Flags -----------------------------------------------------------------
# --raw       : no ROM header (HuCARD doesn't need one)
# --newproc   : .proc trampolines in MPR6 (frees MPR5 for game code)
# --strip     : strip unused .proc / .procgroup blocks
# -gA         : emit a PCEAS-format .SYM for ASM source-level debugging
#               (Geargrafx auto-loads it; Mesen2 also accepts this format)
# -m          : show macro expansions in the .lst
# -l 2        : listing detail level 2
# -S          : append segment usage + contents to stdout after assembly
PCEAS_FLAGS = --raw --newproc --strip -gA -m -l 2 -S

# --- Sources ---------------------------------------------------------------
# Tiered layout: app/ = top-level entry + per-screen modules,
# engine/ = portable game systems, system/ = platform.inc + future HAL.
PCE_ASM    = $(wildcard $(SRCDIR)/pce/app/*.asm) \
             $(wildcard $(SRCDIR)/pce/engine/*.asm) \
             $(wildcard $(SRCDIR)/pce/system/*.asm)
PCE_INC    = $(wildcard $(SRCDIR)/pce/app/*.inc) \
             $(wildcard $(SRCDIR)/pce/engine/*.inc) \
             $(wildcard $(SRCDIR)/pce/system/*.inc)
PCE_MAIN   = $(SRCDIR)/pce/app/boot.asm
PCE_OUT    = $(BUILDDIR)/pce/$(NAME).pce
PCE_SYM    = $(BUILDDIR)/pce/$(NAME).sym
PCE_LST    = $(BUILDDIR)/pce/$(NAME).lst

# --- Phony targets ---------------------------------------------------------
.PHONY: all build build-pce run run-pce load load-pce clean package help check-tools

all: build-pce

# Top-level convenience aliases. While only PCE is wired up, "make build",
# "make run", and "make load" act on the PCE target. When a second platform
# is added, these become explicit (build-x16 / build-neo / etc.) and the
# bare aliases either go away or stay pointing at the primary target.
build: build-pce
run:   run-pce
load:  load-pce

help:
	@echo "Targets:"
	@echo "  build / build-pce   PC Engine / TG-16 (HuC6280) -> $(PCE_OUT)"
	@echo "  run   / run-pce     launch Geargrafx with the ROM (auto-loads"
	@echo "                      $(notdir $(PCE_SYM)) for symbol-aware debug)"
	@echo "  load  / load-pce    alias for run-pce (Geargrafx has no auto-run"
	@echo "                      vs load-only distinction; provided for parity"
	@echo "                      with the multi-platform Makefile convention)"
	@echo "  check-tools         verify pceas + geargrafx are on PATH"
	@echo "  clean               remove build/ and release/"
	@echo "  package             copy ROM + README into release/"

check-tools:
	@command -v $(PCEAS) >/dev/null 2>&1 || \
	    { echo "ERROR: $(PCEAS) not on PATH. Install HuC from"; \
	      echo "       https://github.com/pce-devel/huc and add bin/ to PATH."; \
	      exit 1; }
	@command -v $(GEARGRAFX) >/dev/null 2>&1 || \
	    echo "WARNING: $(GEARGRAFX) not on PATH. run-pce/load-pce will fail until installed."
	@echo "HUC_HOME  = $(HUC_HOME)"
	@echo "PCEAS     = $$(command -v $(PCEAS))"
	@echo "Geargrafx = $$(command -v $(GEARGRAFX) || echo '<not installed>')"

# ===========================================================================
# PC Engine / TurboGrafx-16 (PCEAS)
# ===========================================================================
build-pce: $(PCE_OUT)

# PCEAS writes the .pce wherever -o points, but always drops .sym + .lst
# next to the *input* .asm. We move them into $(BUILDDIR)/pce/ post-build
# so src/ stays clean and the .sym sits beside the .pce where Geargrafx
# auto-discovers it.
PCE_MAIN_STEM = $(basename $(notdir $(PCE_MAIN)))
PCE_SRC_SYM   = $(dir $(PCE_MAIN))$(PCE_MAIN_STEM).sym
PCE_SRC_LST   = $(dir $(PCE_MAIN))$(PCE_MAIN_STEM).lst

$(PCE_OUT): $(PCE_ASM) $(PCE_INC)
	@mkdir -p $(dir $@)
	$(PCEAS) $(PCEAS_FLAGS) -o $@ $(PCE_MAIN)
	@[ -f $(PCE_SRC_SYM) ] && mv $(PCE_SRC_SYM) $(PCE_SYM) || true
	@[ -f $(PCE_SRC_LST) ] && mv $(PCE_SRC_LST) $(PCE_LST) || true

# Geargrafx auto-loads <rom>.sym when present, so we don't need to pass
# $(PCE_SYM) explicitly - the Makefile drops it next to the .pce already.
# Pass it anyway for clarity and so this still works if the user moves
# the rom to a path with a different stem.
run-pce: build-pce
	$(GEARGRAFX) $(PCE_OUT) $(PCE_SYM)

# load-pce: alias for run-pce. Provided for symmetry with the multi-platform
# load-* convention used in sibling repos (where load- variants stage the
# binary in the emulator without auto-running, useful for clean video
# capture). Geargrafx has no equivalent flag, so on PCE the two are the same.
load-pce: run-pce

# ===========================================================================
# Housekeeping
# ===========================================================================
package: all
	@mkdir -p $(RELEASEDIR)
	@cp README.md $(RELEASEDIR)/
	@cp $(PCE_OUT) $(RELEASEDIR)/ 2>/dev/null || true

clean:
	rm -rf $(BUILDDIR) $(RELEASEDIR)
