require 'formula'

class MacvimKaoriya < Formula
  homepage 'https://github.com/splhack/macvim-kaoriya'
  head 'https://github.com/splhack/macvim.git'

  option 'with-properly-linked-python2-python3', 'Link with properly linked Python 2 and Python 3. You will get deadly signal SEGV if you don\'t have properly linked Python 2 and Python 3.'
  option 'with-binary-release', ''

  depends_on 'cmigemo-mk' => :build
  depends_on 'gettext' => :build
  depends_on 'lua' => :build
  #depends_on 'lua@5.1' => :build Homebrew doesn't allow this
  depends_on 'luajit' => :build
  depends_on 'python' => :build
  depends_on 'ruby' => :build
  depends_on 'universal-ctags' => :build

  def get_path(name)
    f = Formulary.factory(name)
    if f.rack.directory?
      kegs = f.rack.subdirs.map { |keg| Keg.new(keg) }.sort_by(&:version)
      return kegs.last.to_s unless kegs.empty?
    end
    nil
  end

  def install
    error = nil
    depend_formulas =
      %w(cmigemo-mk gettext lua lua@5.1 luajit python ruby universal-ctags)
    depend_formulas.each do |formula|
      var = "@" + formula.gsub('-', '_').gsub('@', '').gsub('.', '')
      instance_variable_set(var, get_path(formula))
      if instance_variable_get(var).nil?
        error ||= 'brew install ' + depend_formulas.join(' ') + "\n"
        error += "can't find #{formula}\n"
      end
    end
    raise error unless error.nil?

    if build.with? 'binary-release'
      ENV.delete 'MACOSX_DEPLOYMENT_TARGET'
      ENV.append 'MACOSX_DEPLOYMENT_TARGET', '10.9'
      ENV.append 'CFLAGS', '-mmacosx-version-min=10.9'
      ENV.append 'LDFLAGS', '-mmacosx-version-min=10.9 -headerpad_max_install_names'
      ENV.append 'XCODEFLAGS', 'MACOSX_DEPLOYMENT_TARGET=10.9'
    end
    perl_version = '5.16'
    ENV.delete 'CC'
    ENV.append 'CC', '/usr/bin/clang'
    ENV.append 'CPPFLAGS', "-I#{@cmigemo_mk}/include -I#{@gettext}/include"
    ENV.append 'LDFLAGS', "-L#{@gettext}/lib"
    ENV.append 'VERSIONER_PERL_VERSION', perl_version
    ENV.append 'VERSIONER_PYTHON_VERSION', '2.7'
    ENV.append 'LUA_INC', '/lua5.1'
    ENV.append 'LUA52_INC', '/lua5.3'
    ENV.append 'vi_cv_path_python', '/usr/bin/python'
    ENV.append 'vi_cv_path_python3', "#{@python}/bin/python3"
    ENV.append 'vi_cv_path_plain_lua', "#{@lua51}/bin/lua-5.1"
    ENV.append 'vi_cv_dll_name_perl', "/System/Library/Perl/#{perl_version}/darwin-thread-multi-2level/CORE/libperl.dylib"
    ENV.append 'vi_cv_dll_name_python3', "#{@python}/Frameworks/Python.framework/Versions/3.7/Python"

    opts = []
    if build.with? 'properly-linked-python2-python3'
      opts << '--with-properly-linked-python2-python3'
    end

    system "env" if ENV['HOMEBREW_VERBOSE']

    system './configure', "--prefix=#{prefix}",
                          '--with-features=huge',
                          '--enable-multibyte',
                          '--enable-terminal',
                          '--enable-netbeans',
                          '--with-tlib=ncurses',
                          '--enable-cscope',
                          '--enable-perlinterp=dynamic',
                          '--enable-pythoninterp=dynamic',
                          '--enable-python3interp=dynamic',
                          '--enable-rubyinterp=dynamic',
                          '--with-ruby-command=/usr/bin/ruby',
                          '--enable-ruby19interp=dynamic',
                          "--with-ruby19-command=#{@ruby}/bin/ruby",
                          '--enable-luainterp=dynamic',
                          "--with-lua-prefix=#{@lua51}",
                          '--enable-lua52interp=dynamic',
                          "--with-lua52-prefix=#{@lua}",
                          *opts
    system "cat src/auto/config.mk" if ENV['HOMEBREW_VERBOSE']
    system "cat src/auto/config.log" if ENV['HOMEBREW_VERBOSE']

    system "PATH=$PATH:#{@gettext}/bin make -C src/po MSGFMT=#{@gettext}/bin/msgfmt"
    system 'make'

    prefix.install 'src/MacVim/build/Release/MacVim.app'

    app = prefix + 'MacVim.app/Contents'
    frameworks = app + 'Frameworks'
    macos = app + 'MacOS'
    vimdir = app + 'Resources/vim'
    runtime = vimdir + 'runtime'

    appbin = app + "bin"
    bin = prefix + 'bin'
    mkdir_p bin

    [
      'vim', 'vimdiff', 'view',
      'gvim', 'gvimdiff', 'gview',
      'mvim', 'mvimdiff', 'mview'
    ].each do |t|
      ln_s '../MacVim.app/Contents/bin/mvim', bin + t
    end

    dict = runtime + 'dict'
    mkdir_p dict
    Dir.glob("#{@cmigemo_mk}/share/migemo/utf-8/*").each do |f|
      cp f, dict
    end

    resource("CMapResources").stage do
      cp 'UniJIS-UTF8-H', runtime/'print/UniJIS-UTF8-H.ps'
    end

    cp "#{@luajit}/lib/libluajit-5.1.2.dylib", frameworks
    File.open(vimdir + 'vimrc', 'a').write <<EOL
" Lua interface with embedded luajit
exec "set luadll=".simplify(expand("$VIM/../../Frameworks/libluajit-5.1.2.dylib"))
EOL

    if build.with? 'binary-release'
      cp "#{@universal_ctags}/bin/ctags", macos

      [
        "#{HOMEBREW_PREFIX}/opt/gettext/lib/libintl.8.dylib",
        "#{HOMEBREW_PREFIX}/opt/cmigemo-mk/lib/libmigemo.1.dylib",
      ].each do |lib|
        newname = "@executable_path/../Frameworks/#{File.basename(lib)}"
        system "install_name_tool -change #{lib} #{newname} #{macos + 'Vim'}"
        cp lib, frameworks
      end
    end
  end

  resource("CMapResources") do
    url 'https://raw.githubusercontent.com/adobe-type-tools/cmap-resources/master/Adobe-Japan1-6/CMap/UniJIS-UTF8-H'
    sha256 '29dfdbfe5dc6e9bae41dfc6ae2c1cf7b667f5b69b897c8f14eb91da493937673'
  end
end
