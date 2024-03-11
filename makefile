-include build.cfg

##----------------------------------------------------------------------------##
#   Project Settings                                                           #
##----------------------------------------------------------------------------##

NAME = Demo
TOP = TopEntity

##----------------------------------------------------------------------------##
#   Build Rules                                                                #
##----------------------------------------------------------------------------##

default: bitstream

upload: iceblink-upload

update:
	${CABAL} update

iceblink-upload: ${BUILDDIR}/04-bitstream/${NAME}.bin
	${ICEDUDE} -U flash:w:$<

hdl: ${BUILDDIR}/02-hdl

synth: ${BUILDDIR}/03-net/${NAME}.json

bitstream: ${BUILDDIR}/04-bitstream/${NAME}.bin

${BUILDDIR}/04-bitstream/${NAME}.bin: ${BUILDDIR}/03-net/${NAME}.asc
	mkdir -p ${BUILDDIR}/04-bitstream
	${ICEPACK} $< $@
	echo "Created $@"

${BUILDDIR}/03-net/${NAME}.asc: iceblink.pcf ${BUILDDIR}/03-net/${NAME}.json
	${NEXTPNR} \
    --pcf-allow-unconstrained \
    --no-tmdriv \
    --hx1k \
    --package vq100 \
    --json ${BUILDDIR}/03-net/${NAME}.json \
    --pcf iceblink.pcf \
    --asc $@

${BUILDDIR}/03-net/${NAME}.json: ${BUILDDIR}/02-hdl
	mkdir -p ${BUILDDIR}/03-net
	$(eval VFILES = $(shell find ${BUILDDIR}/02-hdl -name '*.v' ! -name '*testbench*'))
	${YOSYS} -p "synth_ice40 -abc2 -top ${NAME} -json ${BUILDDIR}/03-net/${NAME}.json" ${VFILES}

${BUILDDIR}/02-hdl: src/${TOP}.hs dist-newstyle/packagedb
	rm -Rf ${BUILDDIR}/02-hdl ${BUILDDIR}/03-net ${BUILDDIR}/03-bitstream
	mkdir -p ${BUILDDIR}/01-clash
	${CABAL} exec -- ${CLASH} \
    ${CPP_FLAGS} \
    -outputdir \
    ${BUILDDIR}/01-clash --verilog \
    $<
	rm -Rf ${BUILDDIR}/hdl
	cp -R ${BUILDDIR}/01-clash/${TOP}.topEntity ${BUILDDIR}/02-hdl

dist-newstyle/packagedb:
	${CABAL} build

##----------------------------------------------------------------------------##
#   Cleanup                                                                    #
##----------------------------------------------------------------------------##

clean:
	rm -Rf ${BUILDDIR}
	rm -Rf dist-newstyle

##----------------------------------------------------------------------------##
#   Special Targets                                                            #
##----------------------------------------------------------------------------##

.PHONY: clean iceblink upload iceblink-upload
.SECONDARY:
.SILENT:
