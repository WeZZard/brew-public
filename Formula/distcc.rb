class Distcc < Formula
  desc "Distributed compiler client and server"
  homepage "https://github.com/wezzard/distcc/"
  license "GPL-2.0-or-later"
  revision 1
  head "https://github.com/wezzard/distcc.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "python@3.11"

  resource "libiberty" do
    url "https://ftp.debian.org/debian/pool/main/libi/libiberty/libiberty_20210106.orig.tar.xz"
    sha256 "9df153d69914c0f5a9145e0abbb248e72feebab6777c712a30f1c3b8c19047d4"
  end

  def install
    ENV["PYTHON"] = python3 = which("python3.11")
    site_packages = prefix/Language::Python.site_packages(python3)
    # Use Python stdlib's distutils to work around install issue:
    # /opt/homebrew/Cellar/distcc/3.4_1/lib/python3.11/site-packages/ does NOT support .pth files
    ENV["SETUPTOOLS_USE_DISTUTILS"] = "stdlib"

    # While libiberty recommends that packages vendor libiberty into their own source,
    # distcc wants to have a package manager-installed version.
    # Rather than make a package for a floating package like this, let's just
    # make it a resource.
    buildpath.install resource("libiberty")
    cd "libiberty" do
      system "./configure"
      system "make"
    end
    ENV.append "LDFLAGS", "-L#{buildpath}/libiberty"
    ENV.append_to_cflags "-I#{buildpath}/include"

    # Make sure python stuff is put into the Cellar.
    # --root triggers a bug and installs into HOMEBREW_PREFIX/lib/python2.7/site-packages instead of the Cellar.
    inreplace "Makefile.in", '--root="$$DESTDIR"', "--install-lib=\"#{site_packages}\""
    system "./autogen.sh"
    system "./configure", "--prefix=#{prefix}"
    system "make", "install"
  end

  service do
    run [opt_bin/"../etc"/"commands.allow.sh"]
    run [opt_bin/"distccd", "--daemon"]
    keep_alive true
    working_dir opt_prefix
  end

  test do
    system "#{bin}/distcc", "--version"

    (testpath/"Makefile").write <<~EOS
      default:
      \t@echo Homebrew
    EOS
    assert_match "distcc hosts list does not contain any hosts", shell_output("#{bin}/pump make 2>&1", 1)

    # `pump make` timeout on linux runner and is not reproducible, so only run this test for macOS runners
    if OS.mac?
      ENV["DISTCC_POTENTIAL_HOSTS"] = "localhost"
      assert_match "Homebrew\n", shell_output("#{bin}/pump make")
    end
  end
end
