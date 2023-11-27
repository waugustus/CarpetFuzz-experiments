#
# This Dockerfile for CarpetFuzz-experiments uses Ubuntu 20.04 and
# installs LLVM 12 for afl-clang-lto support.
#

From ubuntu:20.04
# Install required dependencies
RUN apt update
RUN DEBIAN_FRONTEND=noninteractive apt install -y \
    build-essential \
    python3-dev \
    python3-pip \
    python3-setuptools \
    automake \
    cmake \
    git \
    flex \
    bison \
    libglib2.0-dev \
    libpixman-1-dev \
    cargo \
    libgtk-3-dev \
    linux-headers-generic \
    vim \
    wget \
    curl \
    gnupg \
    autoconf \
    libtool \
    screen \
    jq \
    asciidoctor \
    lsb-release

# Install clang-12
RUN echo deb http://apt.llvm.org/$(lsb_release -cs)/ llvm-toolchain-$(lsb_release -cs) main >> /etc/apt/sources.list
RUN wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
RUN apt-get update && apt-get upgrade -y
RUN apt install -y \
    clang-12 \
    clang-tools-12 \
    libc++1-12 \
    libc++-12-dev \
    libc++abi1-12 \
    libc++abi-12-dev \
    libclang1-12 \
    libclang-12-dev \
    libclang-common-12-dev \
    libclang-cpp12 \
    libclang-cpp12-dev \
    liblld-12 \
    liblld-12-dev \
    liblldb-12 \
    liblldb-12-dev \
    libllvm12 \
    libomp-12-dev \
    libomp5-12 \
    lld-12 \
    lldb-12 \
    llvm-12 \
    llvm-12-dev \
    llvm-12-runtime \
    llvm-12-tools 
RUN apt install -y \
    gcc-$(gcc --version|head -n1|sed 's/\..*//'|sed 's/.* //')-plugin-dev \
    libstdc++-$(gcc --version|head -n1|sed 's/\..*//'|sed 's/.* //')-dev
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-12 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-12 100 && \
    update-alternatives --install /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-12 100 && \
    update-alternatives --install /usr/bin/llvm-ranlib llvm-ranlib /usr/bin/llvm-ranlib-12 100 && \
    update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-12 100 && \
    update-alternatives --install /usr/bin/llvm-link llvm-link /usr/bin/llvm-link-12 100

# Prepare Fuzzers
RUN mkdir /root/fuzzer
WORKDIR /root/fuzzer
## AFL++
RUN git clone https://github.com/AFLplusplus/AFLplusplus afl++; cd afl++; git reset --hard  2d640558a09b03e9416b5d87e98cf938b38def9e; \
    make clean all
## AFL
RUN git clone https://github.com/google/AFL afl; cd afl; git reset --hard 61037103ae3722c8060ff7082994836a794f978e; \
    make clean all; cd llvm_mode; make clean all
## AFLfast
RUN git clone https://github.com/mboehme/aflfast; cd aflfast; git reset --hard d1d54caf9850ca4afe2ac634a2a212aa6bb40032; \
    ### Add CPU binding support
    sed -i "7938i \      case 'b': { /* bind CPU core */\n\n        if (cpu_to_bind_given) FATAL(\"Multiple -b options not supported\");\n        cpu_to_bind_given = 1;\n\n        if (sscanf(optarg, \"%u\", &cpu_to_bind) < 1 ||\n            optarg[0] == '-') FATAL(\"Bad syntax used for -b\");\n\n        break;\n\n        }\n" afl-fuzz.c; \
    sed -i "7824s/.*/\  while ((opt = getopt(argc, argv, \"+i:o:f:m:t:b:T:dnCB:S:M:x:Qp:\")) > 0)/" afl-fuzz.c; \
    sed -i "7164i \       \"  -b cpu_id     - bind the fuzzing process to the specified CPU core\"\n" afl-fuzz.c; \
    sed -i "489s/.*/\  if (cpu_to_bind_given) {\n\n    if (cpu_to_bind >= cpu_core_count)\n      FATAL(\"The CPU core id to bind should be between 0 and %u\", cpu_core_count - 1);\n\n    if (cpu_used[cpu_to_bind])\n      FATAL(\"The CPU core \#%u to bind is not free\!\", cpu_to_bind);\n\n    i = cpu_to_bind;\n\n  } else {\n\n    for (i = 0; i < cpu_core_count; i++) if (\!cpu_used[i]) break;\n\n  }/" afl-fuzz.c; \
    sed -i "119i \           cpu_to_bind_given,         /* Specified cpu_to_bind given?     */" afl-fuzz.c; \
    sed -i "99i EXP_ST u32 cpu_to_bind = 0;           /* id of free CPU core to bind      */\n" afl-fuzz.c; \
    make clean all; cd llvm_mode; make clean all; exit 0
## MOPT
RUN git clone https://github.com/puppet-meteor/MOpt-AFL; cd MOpt-AFL; git reset --hard a9a5dc5c0c291c1cdb09b2b7b27d7cbf1db7ce7b; \
    cd ..; mv MOpt-AFL/MOpt/ mopt; rm -rf MOpt-AFL/; cd mopt; \
    ### Add CPU binding support
    sed -i "11933i \      case 'b': { /* bind CPU core */\n\n        if (cpu_to_bind_given) FATAL(\"Multiple -b options not supported\");\n        cpu_to_bind_given = 1;\n\n        if (sscanf(optarg, \"%u\", &cpu_to_bind) < 1 ||\n            optarg[0] == '-') FATAL(\"Bad syntax used for -b\");\n\n        break;\n\n        }\n" afl-fuzz.c; \
    sed -i "11819s/.*/\  while ((opt = getopt(argc, argv, \"+i:o:f:m:t:b:V:T:L:dnCB:S:M:x:Q\")) > 0)/" afl-fuzz.c; \
    sed -i "11152i \       \"  -b cpu_id     - bind the fuzzing process to the specified CPU core\"\n" afl-fuzz.c; \
    sed -i "597s/.*/\  if (cpu_to_bind_given) {\n\n    if (cpu_to_bind >= cpu_core_count)\n      FATAL(\"The CPU core id to bind should be between 0 and %u\", cpu_core_count - 1);\n\n    if (cpu_used[cpu_to_bind])\n      FATAL(\"The CPU core \#%u to bind is not free\!\", cpu_to_bind);\n\n    i = cpu_to_bind;\n\n  } else {\n\n    for (i = 0; i < cpu_core_count; i++) if (\!cpu_used[i]) break;\n\n  }/" afl-fuzz.c; \
    sed -i "172i \           cpu_to_bind_given,         /* Specified cpu_to_bind given?     */" afl-fuzz.c; \
    sed -i "162i EXP_ST u32 cpu_to_bind = 0;           /* id of free CPU core to bind      */\n" afl-fuzz.c; \
    make clean all; cd llvm_mode; make clean all
## CarpetFuzz
RUN git clone --recursive https://github.com/waugustus/CarpetFuzz;
WORKDIR CarpetFuzz
### Install required python modules
RUN pip3 install -r requirements.txt
RUN python3 -m spacy download en_core_web_sm-3.0.0 --direct
RUN ["python3", "-c", "import nltk; nltk.download('averaged_perceptron_tagger'); nltk.download('omw-1.4');nltk.download('punkt');nltk.download('wordnet')"]
### Download the NLP model
RUN wget -P models/ https://allennlp.s3.amazonaws.com/models/elmo-constituency-parser-2020.02.10.tar.gz
### Build submodules
RUN cd fuzzer; make clean all
RUN cd pict; cmake -DCMAKE_BUILD_TYPE=Release -S . -B build && cmake --build build; cd build; ctest -v
RUN git clone https://github.com/waugustus/CarpetFuzz-fuzzer fuzzer_afl; cd fuzzer_afl; git checkout AFL_version; make clean all; cd llvm_mode; make clean all
### Finished
WORKDIR /root/fuzzer
## Download Seeds 
RUN git clone https://github.com/MozillaSecurity/fuzzdata
### Seeds of POWER
RUN wget --no-check-certificate "https://drive.google.com/uc?export=download&id=1wEOcEBUq4F99S-PFV9TWBYMImtlztPFa" -O - | tar xf -

# Prepare Dependency
RUN apt install -y \
    libcurl4-openssl-dev \
    libdeflate-dev \
    libjpeg-dev \
    libjbig-dev \
    libwebp-dev \
    liblzma-dev \
    libogg-dev \
    libvorbis-dev \
    libao-dev \
    libflac-dev \
	libspeex-dev \
	gettext \
	libbz2-dev \
	liblzo2-dev \
	liblz4-dev \
	libonig-dev \
	libpcap-dev \
	tcpdump \
	check \
	kmod \
	gawk \
	libgcrypt-dev \
	libc-ares-dev \
	appstream \
	lpr \
	freeglut3-dev \
	graphviz \
	libappstream-dev \
	libboost-dev \
	libcairo2-dev \
	libde265-dev \
	libdjvulibre-dev \
	libexif-dev \
	libexpat1-dev \
	libfftw3-dev \
	libfontconfig1-dev \
	libfreetype6-dev \
	libgl1-mesa-dev \
	libglew-dev \
	libglfw3-dev \
	libglib2.0-dev \
	libglm-dev \
	libgsl-dev \
	libgslcblas0 \
	libgtksourceview-3.0-dev \
	libheif-dev \
	libjpeg-turbo8-dev \
	libjpeg8-dev \
	liblcms2-dev \
	liblqr-1-0-dev \
	libltdl-dev \
	libnss3-dev \
	libopenexr-dev \
	libopenjp2-7-dev \
	libpango1.0-dev \
	libpcre3-dev \
	libpng-dev \
	libraqm-dev \
	libraw-dev \
	librsvg2-dev \
	libsdl2-dev \
	libsdl2-image-dev \
	libssl-dev \
	libtiff-dev \
	libtiff5-dev \
	libwmf-dev \
	libxml2-dev \
	libxt-dev \
	libzip-dev \
	texinfo \
	zlib1g-dev
RUN pip3 install wllvm sysv-ipc
RUN mkdir /root/dep;
WORKDIR /root/dep
RUN git clone https://github.com/facebook/zstd; cd zstd; make -j install; ln -s /lib/x86_64-linux-gnu/libzstd.so.1 /lib/x86_64-linux-gnu/libzstd.so
RUN git clone https://github.com/esri/lerc; cd lerc; mkdir tmp; cd tmp; cmake ..; make -j install; ln -s /usr/local/lib/libLerc.so /lib/x86_64-linux-gnu/libLerc.so; ln -s /usr/local/lib/libLerc.so.4 /lib/x86_64-linux-gnu/libLerc.so.4
RUN git clone https://github.com/ofalk/libdnet.git; cd libdnet; ./configure; make -j install
RUN git clone https://github.com/luigirizzo/netmap; cd netmap; git reset --hard d67a604e805b67efb563ea8d5eb2d1318acf6ed8; cd LINUX; ./configure; make -j; make install
RUN wget -O- http://alpha.gnu.org/gnu/ssw/spread-sheet-widget-0.8.tar.gz| tar zxv; cd spread-sheet-widget-0.8; ./configure;make -j;make install
RUN rm -rf /usr/local/go && wget -O- https://go.dev/dl/go1.19.3.linux-amd64.tar.gz |tar zxv -C /usr/local; 
RUN echo "export GOPATH=/root/go" >> ~/.bashrc; echo "export PATH=$PATH:/root/go/bin:/usr/local/go/bin" >> ~/.bashrc
ENV GOPATH=/root/go \ 
    PATH=$PATH:/root/go/bin:/usr/local/go/bin
RUN go env -w GO111MODULE=off; go get github.com/SRI-CSL/gllvm/cmd/...

# Prepare build script
RUN /bin/echo -e '#!/bin/bash\nCFLAGS="-g -O0" CXXFLAGS="-g -O0" ./configure --prefix=$PWD/build_orig --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/orig_configure && chmod +x /usr/bin/orig_configure; \
    /bin/echo -e '#!/bin/bash\nCFLAGS="-g -fsanitize=address -fno-omit-frame-pointer" CXXFLAGS="-g -fsanitize=address -fno-omit-frame-pointer" ./configure --prefix=$PWD/build_asan --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/asan_configure && chmod +x /usr/bin/asan_configure; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/afl/afl-clang-fast CXX=/root/fuzzer/afl/afl-clang-fast++ ./configure --prefix=$PWD/build_afl/ --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/afl_configure && chmod +x /usr/bin/afl_configure; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/aflfast/afl-clang-fast CXX=/root/fuzzer/aflfast/afl-clang-fast++ ./configure --prefix=$PWD/build_aflfast/ --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/aflfast_configure && chmod +x /usr/bin/aflfast_configure; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/mopt/afl-clang-fast CXX=/root/fuzzer/mopt/afl-clang-fast++ ./configure --prefix=$PWD/build_mopt/ --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/mopt_configure && chmod +x /usr/bin/mopt_configure; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/afl++/afl-clang-fast CXX=/root/fuzzer/afl++/afl-clang-fast++ ./configure --prefix=$PWD/build_afl++/ --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/afl++_configure && chmod +x /usr/bin/afl++_configure; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/CarpetFuzz/fuzzer_afl/afl-clang-fast CXX=/root/fuzzer/CarpetFuzz/fuzzer_afl/afl-clang-fast++ ./configure --prefix=$PWD/build_carpetfuzz/ --disable-shared "$@"; make -j; make install; make clean' > /usr/bin/carpetfuzz_configure && chmod +x /usr/bin/carpetfuzz_configure; \
    /bin/echo -e '#!/bin/bash\norig_configure "$@"; asan_configure "$@"; afl_configure "$@"; aflfast_configure "$@"; aflfast_configure "$@"; mopt_configure "$@"; afl++_configure "$@"; carpetfuzz_configure "$@"' > /usr/bin/all_configure && chmod +x /usr/bin/all_configure; \
    /bin/echo -e '#!/bin/bash\nCC=gclang CXX=gclang++ ./configure --prefix=$PWD/build_orig --disable-shared "$@"; make -j; make install' > /usr/bin/gclang_configure && chmod +x /usr/bin/gclang_configure
RUN /bin/echo -e '#!/bin/bash\nCFLAGS="-g -O0" CXXFLAGS="-g -O0" cmake .. -DCMAKE_INSTALL_PREFIX=../build_orig  -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/orig_cmake && chmod +x /usr/bin/orig_cmake; \
    /bin/echo -e '#!/bin/bash\nCFLAGS="-g -fsanitize=address -fno-omit-frame-pointer" CXXFLAGS="-g -fsanitize=address -fno-omit-frame-pointer" cmake .. -DCMAKE_INSTALL_PREFIX=../build_asan -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/asan_cmake && chmod +x /usr/bin/asan_cmake; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/afl/afl-clang-fast CXX=/root/fuzzer/afl/afl-clang-fast++ cmake .. -DCMAKE_INSTALL_PREFIX=../build_afl  -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/afl_cmake && chmod +x /usr/bin/afl_cmake; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/aflfast/afl-clang-fast CXX=/root/fuzzer/aflfast/afl-clang-fast++ cmake .. -DCMAKE_INSTALL_PREFIX=../build_aflfast  -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/aflfast_cmake && chmod +x /usr/bin/aflfast_cmake; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/mopt/afl-clang-fast CXX=/root/fuzzer/mopt/afl-clang-fast++ cmake .. -DCMAKE_INSTALL_PREFIX=../build_mopt  -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/mopt_cmake && chmod +x /usr/bin/mopt_cmake; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/afl++/afl-clang-fast CXX=/root/fuzzer/afl++/afl-clang-fast++ cmake .. -DCMAKE_INSTALL_PREFIX=../build_afl++  -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/afl++_cmake && chmod +x /usr/bin/afl++_cmake; \
    /bin/echo -e '#!/bin/bash\nCC=/root/fuzzer/CarpetFuzz/fuzzer_afl/afl-clang-fast CXX=/root/fuzzer/CarpetFuzz/fuzzer_afl/afl-clang-fast++ cmake .. -DCMAKE_INSTALL_PREFIX=../build_carpetfuzz  -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install; rm -rf ./*' > /usr/bin/carpetfuzz_cmake && chmod +x /usr/bin/carpetfuzz_cmake; \
    /bin/echo -e '#!/bin/bash\norig_cmake "$@"; asan_cmake "$@"; afl_cmake "$@"; aflfast_cmake "$@"; mopt_cmake "$@"; afl++_cmake "$@"; carpetfuzz_cmake "$@";' > /usr/bin/all_cmake && chmod +x /usr/bin/all_cmake; \
    /bin/echo -e '#!/bin/bash\nCC=gclang CXX=gclang++ cmake .. -DCMAKE_INSTALL_PREFIX=../build_orig -DBUILD_SHARED_LIBS:BOOL=OFF "$@"; make -j; make install' > /usr/bin/gclang_cmake && chmod +x /usr/bin/gclang_cmake
RUN /bin/echo -e '#!/bin/bash\nget-bc ./build_orig/bin/${program}; mkdir build_orig/target_carpetfuzz++_${program};/root/fuzzer/CarpetFuzz/fuzzer/afl-clang-lto build_orig/bin/${program}.bc ${build_flag} -o build_orig/target_carpetfuzz++_${program}/${program}.afl' > /usr/bin/carpetfuzz++_process && chmod +x /usr/bin/carpetfuzz++_process; \
    # Build afl++ for afl-showmap
    /bin/echo -e '#!/bin/bash\nmkdir build_orig/target_afl++_${program};/root/fuzzer/afl++/afl-clang-lto build_orig/bin/${program}.bc ${build_flag} -o build_orig/target_afl++_${program}/${program}.afl' > /usr/bin/afl++_process && chmod +x /usr/bin/afl++_process; \
    /bin/echo -e '#!/bin/bash\ncp -r /root/fuzzer/init_seeds/${program}/ input_${program}' > /usr/bin/seed_process && chmod +x /usr/bin/seed_process

# Prepare Programs for RQ1-4
RUN mkdir /root/programs; 
WORKDIR /root/programs
## Cmark
RUN git clone https://github.com/commonmark/cmark cmark-git-9c8e8; cd cmark-git-9c8e8; git reset --hard 9c8e8341361fddc94322f9e0d7e9439e50d16138; \
    mkdir build; cd build; all_cmake; cd ..; \
    mkdir input; cp test/afl_test_cases/test.md input/
## Libsixel
RUN git clone https://github.com/saitoha/libsixel libsixel-git-6a5be; cd libsixel-git-6a5be; git reset --hard 6a5be8b72d84037b83a5ea838e17bcf372ab1d5f; \
    all_configure; \
    mkdir input; cp /root/fuzzer/afl++/testcases/images/jpeg/not_kitty.jpg input/
## Libtiff
RUN git clone https://gitlab.com/libtiff/libtiff libtiff-git-b51bb; cd libtiff-git-b51bb; git reset --hard b51bb157123264e26d34c09cc673d213aea61fc7; \
    bash ./autogen.sh; all_configure; \
    mkdir input; cp /root/fuzzer/afl++/testcases/images/tiff/not_kitty.tiff input/
## OpenSSL
RUN git clone https://github.com/openssl/openssl openssl-git-31ff3; cd openssl-git-31ff3; git reset --hard 31ff3635371b51c8180838ec228c164aec3774b6
### We modified the ui_openssl.c to avoid waiting for user input
RUN cd openssl-git-31ff3; sed -i '339s/.*/    p = "123456\\n";\n    strcpy(result, p);/' crypto/ui/ui_openssl.c; \
    CFLAGS="-g -O0" ./config --prefix=$PWD/build_orig no-shared no-module -DPEDANTIC enable-tls1_3 enable-weak-ssl-ciphers enable-rc5 enable-md2 enable-ssl3 enable-ssl3-method enable-nextprotoneg enable-ec_nistp_64_gcc_128 -fno-sanitize=alignment --debug;make -j;make install;make clean; \
    CFLAGS="-g -fsanitize=address -fno-omit-frame-pointer" ./config --prefix=$PWD/build_asan no-shared enable-asan no-module -DPEDANTIC enable-tls1_3 enable-weak-ssl-ciphers enable-rc5 enable-md2 enable-ssl3 enable-ssl3-method enable-nextprotoneg enable-ec_nistp_64_gcc_128 -fno-sanitize=alignment --debug;make -j;make install;make clean; \
    for fuzzer in afl aflfast mopt afl++; do CC=/root/fuzzer/${fuzzer}/afl-clang-fast ./config --prefix=$PWD/build_${fuzzer} enable-fuzz-afl no-shared no-module -DPEDANTIC enable-tls1_3 enable-weak-ssl-ciphers enable-rc5 enable-md2 enable-ssl3 enable-ssl3-method enable-nextprotoneg enable-ec_nistp_64_gcc_128 -fno-sanitize=alignment --debug; make -j; make install; make clean; done; \
    CC=/root/fuzzer/CarpetFuzz/fuzzer_afl/afl-clang-fast ./config --prefix=$PWD/build_carpetfuzz enable-fuzz-afl no-shared no-module -DPEDANTIC enable-tls1_3 enable-weak-ssl-ciphers enable-rc5 enable-md2 enable-ssl3 enable-ssl3-method enable-nextprotoneg enable-ec_nistp_64_gcc_128 -fno-sanitize=alignment --debug; make -j; make install; make clean; \
    mkdir input; mkdir input/ec; mkdir input/rsa; mkdir input/asn1parse; cp test/testecpub-p256.pem input/ec/; cp test/testrsapub.pem input/rsa/; cp test/testx509.pem input/asn1parse/
## Xpdf
RUN wget -O- https://dl.xpdfreader.com/old/xpdf-4.03.tar.gz| tar zxv; cd xpdf-4.03; \
    mkdir build; cd build; all_cmake; cd ..; \
    mkdir input; cp /root/fuzzer/afl++/testcases/others/pdf/small.pdf input/
## Vorbis-tools
RUN wget -O- https://github.com/xiph/vorbis-tools/archive/refs/tags/v1.4.2.tar.gz |tar zxv; cd vorbis-tools-1.4.2/; \
    ./autogen.sh; all_configure; \
    mkdir input; cp /root/fuzzer/fuzzdata/samples/ogg/audio.ogg input/
## Podofo
RUN wget -O- http://sourceforge.net/projects/podofo/files/podofo/0.9.8/podofo-0.9.8.tar.gz/download| tar zxv; cd podofo-0.9.8; \
    mkdir build; cd build; all_cmake; cd ..; \
    mkdir input; cp /root/fuzzer/afl++/testcases/others/pdf/small.pdf input/
## Lrzip
RUN wget -O- https://github.com/ckolivas/lrzip/archive/refs/tags/v0.651.tar.gz|tar zxv; cd lrzip-0.651; \
    ./autogen.sh; all_configure; \
    mkdir input; cp /root/fuzzer/afl++/testcases/archives/exotic/lrzip/small_archive.lrz input
## Speex
RUN wget -O- https://github.com/xiph/speex/archive/refs/tags/Speex-1.2.1.tar.gz|tar zxv; cd speex-Speex-1.2.1; \
    ./autogen.sh; all_configure; \
    mkdir input; cp /root/fuzzer/fuzzdata/samples/speex/sample.spx input
## Jpegoptim
RUN wget -O- https://github.com/tjko/jpegoptim/archive/refs/tags/v1.5.0.tar.gz|tar zxv; cd jpegoptim-1.5.0; \
    all_configure; \
    mkdir input; cp /root/fuzzer/afl++/testcases/images/jpeg/not_kitty.jpg input/
## Jq
RUN wget -O- https://github.com/stedolan/jq/releases/download/jq-1.6/jq-1.6.tar.gz|tar zxv; cd jq-1.6; \
    all_configure; \
    ### Modify the manpage to adapt to the parsing script
    sed -i "36s/.*/\.SH \"OPTIONS\"/"  build_orig/share/man/man1/jq.1; \
    mkdir input; cp tests/modules/data.json input/
## Libjpeg-turbo
RUN wget -O- https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/2.1.4.tar.gz|tar zxv; cd libjpeg-turbo-2.1.4; \
    mkdir build; cd build; all_cmake; cd ..; \
    mkdir input; cp /root/fuzzer/afl++/testcases/images/jpeg/not_kitty.jpg input/
## Tcpreplay
RUN wget -O- https://github.com/appneta/tcpreplay/releases/download/v4.4.2/tcpreplay-4.4.2.tar.xz|tar xJ; cd tcpreplay-4.4.2; \
    all_configure --enable-debug; \
    mkdir input; cp /root/fuzzer/afl++/testcases/others/pcap/small_capture.pcap input/; ./build_orig/bin/tcpprep -a client -i input/small_capture.pcap -o small_capture.cache
## Elfutil
RUN wget -O- https://sourceware.org/elfutils/ftp/0.188/elfutils-0.188.tar.bz2|tar xvj; cd elfutils-0.188; \
    for cmd in "orig_configure" "asan_configure"; do ${cmd} --enable-elf-stt-common --enable-elf-stt-common --enable-maintainer-mode --disable-debuginfod --disable-libdebuginfod --without-bzlib --without-lzma --without-zstd CFLAGS="-Wno-error $CFLAGS";done; \
    ### Use wllvm to avoid compilation errors
    LLVM_COMPILER=clang CC=wllvm CFLAGS="-Wno-error" ./configure --prefix=$PWD/build_afl --enable-elf-stt-common --enable-elf-stt-common --enable-maintainer-mode --disable-debuginfod --disable-libdebuginfod --without-bzlib --without-lzma --without-zstd;LLVM_COMPILER=clang make -j;make install;make clean; \
    for fuzzer in aflfast mopt afl++ carpetfuzz;do cp -r build_afl build_${fuzzer};done; \
    for fuzzer in afl aflfast mopt afl++;do for program in `ls build_${fuzzer}/bin/`;do extract-bc build_${fuzzer}/bin/eu-elfclassify;/root/fuzzer/${fuzzer}/afl-clang-fast build_${fuzzer}/bin/eu-elfclassify.bc -o build_${fuzzer}/bin/eu-elfclassify -L$PWD/build_${fuzzer}/lib -lelf -ldw -lstdc++ -lasm;done;done; \
    extract-bc build_carpetfuzz/bin/eu-elfclassify;/root/fuzzer/CarpetFuzz/fuzzer_afl/afl-clang-fast build_carpetfuzz/bin/eu-elfclassify.bc -o build_carpetfuzz/bin/eu-elfclassify -L$PWD/build_carpetfuzz/lib -lelf -ldw -lstdc++ -lasm; \
    mkdir input; cp /root/fuzzer/afl++/testcases/others/elf/small_exec.elf input/
## Wireshark
RUN wget -O- https://2.na.dl.wireshark.org/src/all-versions/wireshark-4.0.1.tar.xz|tar xJ; cd wireshark-4.0.1/; \
    mkdir build; cd build; all_cmake -DBUILD_wireshark=OFF; cd ..; \
    mkdir input; cp /root/fuzzer/afl++/testcases/others/pcap/small_capture.pcap input/

# Prepare Programs for RQ5
RUN mkdir /root/programs_rq5
WORKDIR /root/programs_rq5
## We use the same compilation method as POWER (i.e. via gllvm)
## Libav
RUN git clone https://github.com/libav/libav libav-git-c464278; cd libav-git-c464278; git reset --hard c464278; \
    gclang_configure --disable-asm --cc=gclang; \ 
    export program="avconv";export build_flag="-lz -lm -lpthread -lasound -lsndio -lbz2 -ldl -lrt";carpetfuzz++_process;afl++_process;seed_process
## Bison
RUN wget -O- https://ftp.gnu.org/gnu/bison/bison-3.7.6.tar.gz|tar zxv;cd bison-3.7.6; \
    gclang_configure; \
    export program="bison";export build_flag="-lc";carpetfuzz++_process;afl++_process;seed_process
## Cflow
RUN wget -O- https://ftp.gnu.org/gnu/cflow/cflow-1.6.tar.gz|tar zxv; cd cflow-1.6; \
    gclang_configure; \
    export program="cflow";export build_flag="-lc";carpetfuzz++_process;afl++_process;seed_process
## Libjpeg-turbo-2.1.0
RUN wget -O- https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/2.1.0.tar.gz |tar zxv; cd libjpeg-turbo-2.1.0; \
    mkdir build; cd build; gclang_cmake; cd ..;\
    export build_flag="-L$PWD/build_orig/lib -lc -ljpeg"; for program in "cjpeg" "djpeg"; do export program=${program}; carpetfuzz++_process;afl++_process;seed_process; done
## Libdwarf
RUN wget -O- https://www.prevanders.net/libdwarf-20210528.tar.gz |tar zxv; cd libdwarf-20210528; \
    gclang_configure; \
    export program="dwarfdump";export build_flag="-lz -lc";carpetfuzz++_process;afl++_process;seed_process
## Exiv2
RUN wget -O- https://github.com/Exiv2/exiv2/archive/refs/tags/v0.27.4.tar.gz |tar zxv; cd exiv2-0.27.4; \
    mkdir build; cd build; gclang_cmake; cd ..; \
    export program="exiv2";export build_flag="-lexpat -lpthread -lz -lc -lstdc++ -lm -lgcc_s";carpetfuzz++_process;afl++_process;seed_process
## Ffmpeg
RUN git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg-N-103440-g2f0113be3f; cd ffmpeg-N-103440-g2f0113be3f; git reset --hard 2f0113be3f; \
    gclang_configure --disable-asm --cc=gclang; \
    export program="ffmpeg";export build_flag="-lm -lxcb -lxcb-shm -lasound -lSDL2 -lsndio -lXv -lX11 -lXext -lbz2 -llzma -ldl -lpulse -lXcursor -lXinerama -lXi -lXrandr -lXss -lXxf86vm -lz -lpthread -lc -lXau -lXdmcp";carpetfuzz++_process;afl++_process;seed_process
## Graphicsmagick
RUN wget -O- https://sourceforge.net/projects/graphicsmagick/files/graphicsmagick/1.3.36/GraphicsMagick-1.3.36.tar.gz/download |tar zxv; cd GraphicsMagick-1.3.36; \
    gclang_configure  --without-zstd; \
    export program="gm";export build_flag="-ljbig -lwebp -lwebpmux -llcms2 -ltiff -lfreetype -ljpeg -lpng16 -lXext -lSM -lICE -lX11 -llzma -lbz2 -lxml2 -lz -lm -lpthread -lomp -lc -luuid -lxcb -ldl -licuuc -lrt -lXau -lXdmcp -licudata -lstdc++ -lgcc_s -lwmflite -lzstd";carpetfuzz++_process;afl++_process;seed_process
## Ghostpdl
RUN wget -O- https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs9540/ghostpdl-9.54.0.tar.gz |tar zxv; cd ghostpdl-9.54.0; \
    gclang_configure LDFLAGS="-ldeflate"; \
    export program="gs";export build_flag="-ldeflate -lm -ldl -lfontconfig -lfreetype -lpthread -lstdc++ -lgcc_s -lc -lexpat -luuid -lpng16 -lz";carpetfuzz++_process;afl++_process;seed_process
## Jasper
RUN wget -O- https://github.com/jasper-software/jasper/releases/download/version-2.0.32/jasper.tar.gz|tar zxv; cd jasper-2.0.32; \
    mkdir tmp;cd tmp; gclang_cmake -DJAS_ENABLE_LIBJPEG=true -DJAS_ENABLE_SHARED=false; cd ..; \
    export program="jasper";export build_flag="-ljasper -ljpeg -lm -lc";carpetfuzz++_process;afl++_process;seed_process
## Mpg123
RUN wget -O- https://sourceforge.net/projects/mpg123/files/mpg123/1.28.2/mpg123-1.28.2.tar.bz2/download |tar xvj; cd mpg123-1.28.2; \
    gclang_configure --with-cpu=generic; \
    export program="mpg123";export build_flag="-lpulse-simple -lpulse -lm -lc -lpthread -ldbus-1 -ldl -lxcb -lrt -lXau -lXdmcp -llzma -llz4 -lgcrypt -lnsl -lFLAC -logg -lvorbis -lvorbisenc -lresolv -lgpg-error";carpetfuzz++_process;afl++_process;seed_process
## Mupdf
RUN git clone --recursive git://git.ghostscript.com/mupdf.git mupdf-git-d00de0e;cd mupdf-git-d00de0e; git reset --hard d00de0e; git submodule update --init; \
    CC=gclang CXX=gclang++ make HAVE_X11=no HAVE_GLUT=no shared=no prefix=$PWD/build_orig install; \
    export program="mutool";export build_flag="-L$PWD/build_orig/lib -lmupdf -ldl -lcrypto -lm -lpthread -lc";carpetfuzz++_process;afl++_process;seed_process
## Nasm
RUN wget -O- https://www.nasm.us/pub/nasm/releasebuilds/2.15.05/nasm-2.15.05.tar.gz|tar zxv; cd nasm-2.15.05; \
    gclang_configure; \
    export program="nasm";export build_flag="-lc";carpetfuzz++_process;afl++_process;seed_process
## Binutils
RUN wget -O- https://ftp.gnu.org/gnu/binutils/binutils-2.36.1.tar.gz| tar zxv; cd binutils-2.36.1/; \
    gclang_configure; \
    export build_flag="-lc -ldl"; for program in objdump readelf size; do export program=${program}; carpetfuzz++_process;afl++_process;seed_process; done
## Poppler
RUN wget -O- https://poppler.freedesktop.org/poppler-21.07.0.tar.xz |tar xvJ; cd poppler-21.07.0; \
    mkdir build; cd build; gclang_cmake -DENABLE_QT5=OFF -DENABLE_QT6=OFF; cd ..; \
    export program="pdftohtml";export build_flag="-lfreetype -lfontconfig -ljpeg -lcurl -lnss3 -lnssutil3 -lsmime3 -lssl3 -lplds4 -lplc4 -lnspr4 -lopenjp2 -lm -lpthread -llcms2 -lpng16 -lz -ltiff -lstdc++ -lgcc_s -lc -lexpat -ldl -lrt -llzma -ljbig -lffi -lcrypt";carpetfuzz++_process;afl++_process;seed_process
## Xpdf
RUN wget -O- https://dl.xpdfreader.com/old/xpdf-4.03.tar.gz|tar zxv; cd xpdf-4.03; \
    mkdir build; cd build; gclang_cmake; cd ..; \
    export build_flag="-lfreetype -lpng16 -lz -lfontconfig -lpthread -lstdc++ -lm -lc -lexpat"; for program in pdftopng pdftops; do export program=${program}; carpetfuzz++_process;afl++_process;seed_process; done
## Libpng
RUN wget -O- https://sourceforge.net/projects/libpng/files/libpng16/1.6.37/libpng-1.6.37.tar.gz/download|tar zxv;cd libpng-1.6.37; \
    gclang_configure; \
    export program="pngfix";export build_flag="-lz -lm -lc";carpetfuzz++_process;afl++_process;seed_process
## Pspp
RUN wget -O- https://ftp.gnu.org/gnu/pspp/pspp-1.4.1.tar.gz |tar zxv; cd pspp-1.4.1; \
    gclang_configure --without-perl-module --disable-shared; \
    export program="pspp";export build_flag="-lxml2 -lpangocairo-1.0 -lpango-1.0 -lgobject-2.0 -lglib-2.0 -lcairo -lgsl -lgslcblas -lz -lm -lc -ldl -licuuc -llzma -lfontconfig -lpangoft2-1.0 -lfreetype -lpthread -lffi -lpcre -lpixman-1 -lpng16 -lxcb-shm -lxcb -lxcb-render -lXrender -lX11 -lXext -lrt -licudata -lstdc++ -lgcc_s -lexpat -lharfbuzz -lXau -lXdmcp -lgraphite2";carpetfuzz++_process ;afl++_process;seed_process
## Libtiff
RUN wget -O- https://download.osgeo.org/libtiff/tiff-4.3.0.tar.gz|tar zxv; cd tiff-4.3.0; \
    gclang_configure; \
    export build_flag="-lwebp -lzstd -llzma -lLerc -ljbig -ljpeg -ldeflate -lz -lm -lc -lpthread -lstdc++ -lgcc_s"; for program in tiff2pdf tiff2ps tiffinfo; do export program=${program}; carpetfuzz++_process;afl++_process;seed_process; done
## Vim
RUN git clone https://github.com/vim/vim.git vim-8.2.3113; cd vim-8.2.3113; git checkout v8.2.3113; \
    gclang_configure; \
    export program="vim";export build_flag="-lgtk-3 -lgdk-3 -lpangocairo-1.0 -lpango-1.0 -lcairo -lgdk_pixbuf-2.0 -lgio-2.0 -lgobject-2.0 -lglib-2.0 -lSM -lICE -lXt -lX11 -lm -ltinfo -lselinux -ldl -lc -lgmodule-2.0 -lXi -lXfixes -lcairo-gobject -latk-1.0 -latk-bridge-2.0 -lepoxy -lfribidi -lpangoft2-1.0 -lharfbuzz -lfontconfig -lfreetype -lpthread -lXinerama -lXrandr -lXcursor -lXcomposite -lXdamage -lxkbcommon -lwayland-cursor -lwayland-egl -lwayland-client -lXext -lrt -lthai -lpixman-1 -lpng16 -lxcb-shm -lxcb -lxcb-render -lXrender -lz -lmount -lresolv -lffi -lpcre -luuid -lpcre2-8 -ldbus-1 -latspi -lgraphite2 -lexpat -ldatrie -lXau -lXdmcp -lblkid -llzma -llz4 -lgcrypt -lgpg-error";carpetfuzz++_process;afl++_process;seed_process
## Libxml
RUN wget -O- http://xmlsoft.org/download/libxml2-2.9.12.tar.gz|tar zxv; cd libxml2-2.9.12; \
    gclang_configure; \
    export build_flag="-ldl -lz -llzma -lm -lc -lpthread"; for program in xmlcatalog xmllint; do export program=${program}; carpetfuzz++_process;afl++_process;seed_process;done
## Libexpat
RUN wget -O- https://github.com/libexpat/libexpat/releases/download/R_2_4_1/expat-2.4.1.tar.gz |tar zxv; cd expat-2.4.1; \
    gclang_configure; \
    export program="xmlwf";export build_flag="-lc";carpetfuzz++_process;afl++_process;seed_process
## Yara
RUN wget -O- https://github.com/VirusTotal/yara/archive/refs/tags/v4.1.1.tar.gz|tar zxv; cd yara-4.1.1; \
    ./bootstrap.sh; gclang_configure; \
    export program="yara";export build_flag="-lcrypto -lm -lpthread -lc -ldl";carpetfuzz++_process;afl++_process;seed_process

# Clone CarpetFuzz-experiments repo
WORKDIR /root
RUN git clone https://github.com/waugustus/CarpetFuzz-experiments

# All finished
WORKDIR /root/CarpetFuzz-experiments
