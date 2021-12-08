# Use packages
ifndef libsfx_packages
libsfx_packages := 
endif
ifndef derived_files
derived_files := 
endif

libsfx_packages += LZ4

# Derived data files
derived_files	+= common/graphics/font.png.tiles common/graphics/font.png.palette
derived_files   += common/graphics/font.png.tiles.lz4
common/graphics/font.png.palette: palette_flags= -C 4 -W 16 -H 16 -v
common/graphics/font.png.tiles: tiles_flags= --bpp 4 -W 16 -H 16 --no-discard --no-flip -v

derived_files	+= common/graphics/font2.png.tiles common/graphics/font2.png.palette
derived_files   += common/graphics/font2.png.tiles.lz4
common/graphics/font2.png.palette: palette_flags= -C 4 -W 16 -H 16 -v
common/graphics/font2.png.tiles: tiles_flags= --bpp 2 -W 16 -H 16  --no-discard --no-flip -v

export LIBSFX_RUNCMD = bsnes-accuracy $(realpath $(rom))

libsfx_dir	:= ../../../../libSFX

# Validate variables
ifndef name
name		:= out
endif

ifeq ($(name),)
name 		:= out
endif

ifndef debug
debug		:= 2
endif

# Output
rom		:= $(name).sfc

# Default rule
.SUFFIXES:
.PHONY: clean

default: $(rom)

# Tools
libsfx_bin	:= $(libsfx_dir)/tools
as		:= $(libsfx_bin)/cc65/bin/ca65
ld		:= $(libsfx_bin)/cc65/bin/ld65
sfcheck		:= $(libsfx_bin)/superfamicheck/bin/superfamicheck
superfamiconv	:= $(libsfx_bin)/superfamiconv/bin/superfamiconv
brr_enc		:= $(libsfx_bin)/brrtools/bin/brr_encoder
lz4_compress	:= $(libsfx_bin)/lz4/programs/lz4
make_bp		:= $(libsfx_bin)/make_breakpoints

rwildcard = $(strip $(filter $(if $2,$2,%),$(foreach f,$(wildcard $1*),$(eval t = $(call rwildcard,$f/)) $(if $t,$t,$f))))

# File extensions
debug_sym_ext	:= cpu.sym
debug_map_ext	:= dmap
debug_nfo_ext	:= dnfo

# Set defaults
ifndef obj_dir
obj_dir		:= .build
endif
ifndef stack_size
stack_size	:= 100
endif
ifndef zpad_size
zpad_size	:= 10
endif
ifndef znmi_size
znmi_size	:= 10
endif
ifndef rpad_size
rpad_size	:= 100
endif

obj_dir_sfx	:= $(obj_dir)_libsfx

# Flags
libsfx_inc	:= $(libsfx_dir)/include
asflags		:= -D __STACKSIZE__=\$$$(stack_size) -D __ZPADSIZE__=\$$$(zpad_size) -D __ZNMISIZE__=\$$$(znmi_size) -D __RPADSIZE__=\$$$(rpad_size)
ldflags       	:=

ifeq ($(debug),1)
asflags 	+= -D __DEBUG__=1
ldflags 	+= -Ln $(name).$(debug_sym_ext)
endif
ifeq ($(debug),2)
asflags 	+= -D __DEBUG__=1
ldflags 	+= -Ln $(name).$(debug_sym_ext) -m $(name).$(debug_map_ext) -vm --dbgfile $(name).$(debug_nfo_ext)
endif

asflags		+= -g -U -I ./ -I $(libsfx_inc) -I $(libsfx_inc)/Configurations
ldflags		+= --cfg-path ./ --cfg-path $(libsfx_inc)/Configurations/
brr_flags	:= -rn1.0 -g
lz4_flags	:= -f -9
palette_flags   := -v
tiles_flags     := -v
map_flags       := -v


# Include all source files under working directory if $(src) isn't set
ifndef src
src		:= $(call rwildcard, ,%.s)
endif
ifndef headers
headers		:= $(call rwildcard, ,%.i) $(call rwildcard, ,%.i700)
endif

# libSFX
libsfx_src	:= $(wildcard $(libsfx_inc)/CPU/*.s)
libsfx_src_smp	:= $(wildcard $(libsfx_inc)/SMP/*.s700)
libsfx_headers	:= $(call rwildcard,$(libsfx_inc)/,%.i) $(call rwildcard,$(libsfx_inc)/,%.i700)

# Include libSFX package configs
sfx_incs	:= $(foreach inc,$(addprefix $(libsfx_inc)/Packages/,$(libsfx_packages)),$(wildcard $(inc)/config))
include $(sfx_incs)

# Configuration file dependencies
cfg_files	:= Makefile
ifneq ("$(wildcard libSFX.cfg)","")
cfg_files	+= libSFX.cfg
endif
ifneq ("$(wildcard Map.cfg)","")
cfg_files	+= Map.cfg
endif

# Source -> obj targets
obj_sfx		:= $(patsubst $(libsfx_inc)%,$(obj_dir_sfx)%,$(patsubst %.s,%.o,$(libsfx_src)))
obj_smp_sfx	:= $(patsubst $(libsfx_inc)%,$(obj_dir_sfx)%,$(patsubst %.s700,%.o700,$(libsfx_src_smp)))
obj		:= $(patsubst %,$(obj_dir)/%,$(patsubst %.s,%.o,$(src)))

derived_files += $(addsuffix .lz4,$(call rwildcard, ,%.txt))

# Rules
all: clean default

run: $(rom)
ifdef LIBSFX_RUNCMD
  ifndef breakpoints
	$(LIBSFX_RUNCMD) $(run_args)
  else
	$(LIBSFX_RUNCMD) $(run_args) $$($(make_bp) $(breakpoints))
  endif
else
	@echo NB! To enable running set LIBSFX_RUNCMD, for example \(macOS\):
	@echo \ \ \ \ export LIBSFX_RUNCMD\=\'open -a \~/bsnes/bsnes+.app --args \$$\(realpath \$$\(rom\)\)\'
endif

clean:
	@rm -f $(rom) *.$(debug_sym_ext) *.$(debug_map_ext) *.$(debug_nfo_ext) $(derived_files) $(clean_files)
	@rm -frd $(obj_dir) $(obj_dir_sfx) $(clean_dirs)


# Prerequisite rules
$(derived_files) : $(cfg_files)
$(obj) : $(derived_files) $(cfg_files) $(headers) $(libsfx_headers)
$(obj_sfx) : $(cfg_files) $(libsfx_headers)
$(obj_smp_sfx) : $(cfg_files) $(libsfx_headers)

# Link
$(rom) : $(obj_sfx) $(obj_smp_sfx) $(obj)
	$(ld) $(ldflags) -C Map.cfg -o $@ $^
	$(sfcheck) $@ -f

# Project obj : src
$(obj_dir)/%.o : %.s
	@mkdir -pv $(dir $@)
	$(as) $(asflags) $(pkg_asflags) -o $@ $<

# libSFX obj : src
$(obj_dir_sfx)/%.o : $(libsfx_inc)/%.s
	@mkdir -pv $(dir $@)
	$(as) $(asflags) $(pkg_asflags) -o $@ $<

$(obj_dir_sfx)/%.o700 : $(libsfx_inc)/%.s700
	@mkdir -pv $(dir $@)
	$(as) $(asflags) $(pkg_asflags) -D TARGET_SMP -o $@ $<

# Derived file transformations
$(filter %.palette,$(derived_files)) : %.palette : %
	$(superfamiconv) palette $(palette_flags) --in-image $* --out-data $@

$(filter %.tiles,$(derived_files)) : %.tiles : % %.palette
	$(superfamiconv) tiles $(tiles_flags) --in-image $* --in-palette $*.palette --out-data $@

$(filter %.map,$(derived_files)) : %.map : % %.palette %.tiles
	$(superfamiconv) map $(map_flags) --in-image $* --in-palette $*.palette --in-tiles $*.tiles --out-data $@

$(filter %.m7d,$(derived_files)) : %.m7d : % %.palette %.tiles
	$(superfamiconv) map $(map_flags) --mode snes_mode7 --in-image $* --in-palette $*.palette --in-tiles $*.tiles --out-m7-data $@

$(filter %.lz4,$(derived_files)) : %.lz4 : %
	$(lz4_compress) $(lz4_flags) $* $@
	@touch $@
