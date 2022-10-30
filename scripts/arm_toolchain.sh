#! /bin/bash

# Created by Lubos Kuzma
# ISS Program, SADT, SAIT
# August 2022


if [ $# -lt 1 ]; then
        echo "Usage:"
        echo ""
        echo "arm_toolchain.sh  [-p | --port <port number, default 12222>] <assembly filename> [-o | --output <output filename>]"
        echo ""
        echo "Raspberry Pi 3B default or use '-rp4' to use Raspberry Pi4"
        echo""
        echo "-v    | --verbose                Show some information about steps performed."
        echo "-g    | --gdb                    Run gdb command on executable."
        echo "-b    | --break <break point>    Add breakpoint after running gdb. Default is main."
        echo "-r    | --run                    Run program in gdb automatically. Same as run command inside gdb env."
        echo "-rp4  |                          Using Raspberry 4 (64bit)."
        echo "-q    | --qemu                   Run executable in QEMU emulator. This will execute the program."
        echo "-p    | --port                   Specify a port for communication between QEMU and GDB. Default is 12222."
        echo "-o    | --output <filename>      Output filename."

        exit 1
fi

POSITIONAL_ARGS=()
GDB=False
OUTPUT_FILE=""
VERBOSE=False
BITS=False # variable for ARM64
QEMU=False
PORT="12222"
BREAK="main"
RUN=False
RP3B=True  # default Raspberry Pi 3B
RP4=False  

while [[ $# -gt 0 ]]; do
        case $1 in
                -g|--gdb)
                        GDB=True
                        shift # past argument
                        ;;
                -o|--output)
                        OUTPUT_FILE="$2"
                        shift # past argument
                        shift # past value
                        ;;
                -v|--verbose)
                        VERBOSE=True
                        shift # past argument
                        ;;
                -64|--arm-64)
                        BITS=True
                        shift # past argument
                        ;;
                -q|--qemu)
                        QEMU=True
                        shift # past argument
                        ;;
                -r|--run)
                        RUN=True
                        shift # past argument
                        ;;
                 -rp4|)
                        RP4=True
                        RP3B=False # Raspberry Pi 3B will be false as RP4 is used
                        shift # past argument
                        ;;
                -b|--break)
                        BREAK="$2"
                        shift # past argument
                        shift # past value
                        ;;
                -p|--port)
                        PORT="$2"
                        shift
                        shift
                        ;;
                -*|--*)
                        echo "Unknown option $1"
                        exit 1
                        ;;
                *)
                        POSITIONAL_ARGS+=("$1") # save positional arg
                        shift # past argument
                        ;;
        esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ ! -f $1 ]]; then
        echo "Specified file does not exist"
        exit 1
fi

if [ "$OUTPUT_FILE" == "" ]; then
        OUTPUT_FILE=${1%.*}
fi

if [ "$VERBOSE" == "True" ]; then
        echo "Arguments being set:"
        echo "  GDB = ${GDB}"
        echo "  RUN = ${RUN}"
        echo "  BREAK = ${BREAK}"
        echo "  QEMU = ${QEMU}"
        echo "  Input File = $1"
        echo "  Output File = $OUTPUT_FILE"
        echo "  Verbose = $VERBOSE"
        echo "  Port = $PORT" 
        echo ""

        echo "Compiling started..."

fi

if [ "$RP3B" == "True" ]; then
# Raspberry Pi 3B
arm-linux-gnueabihf-gcc -ggdb -mfpu=vfp -march=armv6+fp -mabi=aapcs-linux $1 -o $OUTPUT_FILE -static -nostdlib &&

fi

if [ "$RP4" == "True" ]; then
# Raspberry Pi 4
arm-linux-gnueabihf-gcc -ggdb -march=armv8-a+fp+simd -mabi=aapcs-linux $1 -o $OUTPUT_FILE -static -nostdlib &&

fi

if [ "$VERBOSE" == "True" ]; then

        echo "Compiling finished"

fi

if [ "$BITS" == "True"]; then   # if condition for compiling ARM64 assembly

        echo "Compiling ARM64..."
        aarch64-linux-gnu-as $OUTPUT_FILE.s -o $OUTPUT_FILE.on
        aarch64-linux-gnu-gcc $OUTPUT_FILE.o -o $OUTPUT_FILE.elif -nostdlib -static
        qemu-aarch64 ./$OUTPUT_FILE.elf

fi

if [ "$QEMU" == "True" ] && [ "$GDB" == "False" ]; then
        # Only run QEMU
        echo "Starting QEMU ..."
        echo ""

        qemu-arm $OUTPUT_FILE && echo ""

        exit 0

elif [ "$QEMU" == "False" ] && [ "$GDB" == "True" ]; then
        # Run QEMU in remote and GDB with remote target

        echo "Starting QEMU in Remote Mode listening on port $PORT ..."
        qemu-arm -g $PORT $OUTPUT_FILE &


        gdb_params=()
        gdb_params+=(-ex "target remote 127.0.0.1:${PORT}")
        gdb_params+=(-ex "b ${BREAK}")

        if [ "$RUN" == "True" ]; then

                gdb_params+=(-ex "r")

        fi

        echo "Starting GDB in Remote Mode connecting to QEMU ..."
        sudo gdb-multiarch "${gdb_params[@]}" $OUTPUT_FILE &&

        exit 0

elif [ "$QEMU" == "False" ] && [ "$GDB" == "False" ]; then
        # Don't run either and exit normally

        exit 0

else
        echo ""
        echo "****"
        echo "*"
        echo "* You can't use QEMU (-q) and GDB (-g) options at the same time."
        echo "* Defaulting to QEMU only."
        echo "*"
        echo "****"
        echo ""
        echo "Starting QEMU ..."
        echo ""

        qemu-arm $OUTPUT_FILE && echo ""
        exit 0

fi
