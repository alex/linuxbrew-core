class OpenMpi < Formula
  desc "High performance message passing library"
  homepage "https://www.open-mpi.org/"
  url "https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.3.tar.bz2"
  sha256 "1402feced8c3847b3ab8252165b90f7d1fa28c23b6b2ca4632b6e4971267fd03"

  bottle do
    sha256 "3b143cf02a5345bb0d4df0777d3a34f806ff7fb66dc5d21993b8c4f218722ac7" => :catalina
    sha256 "1600986b4774f6081191fe616cc70690d0174c4a32f4d7f280285ddc39970437" => :mojave
    sha256 "71df1f5047b812b68f8b28f7a6c713f42389691b2269408c8d839f1922ab9e5c" => :high_sierra
  end

  head do
    url "https://github.com/open-mpi/ompi.git"
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "gcc"
  depends_on "hwloc"
  depends_on "libevent"

  conflicts_with "mpich", :because => "both install MPI compiler wrappers"

  def install
    # Fix libopen-pal.so: undefined reference to `__atomic_compare_exchange_16'
    ENV["HOMEBREW_OPTFLAGS"] = "" if !OS.mac? && build.bottle?

    # otherwise libmpi_usempi_ignore_tkr gets built as a static library
    ENV["MACOSX_DEPLOYMENT_TARGET"] = MacOS.version

    ENV.cxx11

    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-silent-rules
      --enable-ipv6
      --with-libevent=#{Formula["libevent"].opt_prefix}
      --with-sge
    ]
    args << "--with-platform-optimized" if build.head?

    system "./autogen.pl" if build.head?
    system "./configure", *args
    system "make", "all"
    system "make", "check"
    system "make", "install"

    # Fortran bindings install stray `.mod` files (Fortran modules) in `lib`
    # that need to be moved to `include`.
    include.install Dir["#{lib}/*.mod"]
  end

  test do
    (testpath/"hello.c").write <<~EOS
      #include <mpi.h>
      #include <stdio.h>

      int main()
      {
        int size, rank, nameLen;
        char name[MPI_MAX_PROCESSOR_NAME];
        MPI_Init(NULL, NULL);
        MPI_Comm_size(MPI_COMM_WORLD, &size);
        MPI_Comm_rank(MPI_COMM_WORLD, &rank);
        MPI_Get_processor_name(name, &nameLen);
        printf("[%d/%d] Hello, world! My name is %s.\\n", rank, size, name);
        MPI_Finalize();
        return 0;
      }
    EOS
    system bin/"mpicc", "hello.c", "-o", "hello"
    system "./hello"
    system bin/"mpirun", "--allow-run-as-root", "./hello"
    (testpath/"hellof.f90").write <<~EOS
      program hello
      include 'mpif.h'
      integer rank, size, ierror, tag, status(MPI_STATUS_SIZE)
      call MPI_INIT(ierror)
      call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierror)
      call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierror)
      print*, 'node', rank, ': Hello Fortran world'
      call MPI_FINALIZE(ierror)
      end
    EOS
    system bin/"mpif90", "hellof.f90", "-o", "hellof"
    system "./hellof"
    system bin/"mpirun", "--allow-run-as-root", "./hellof"
  end
end
