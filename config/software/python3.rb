#
# Copyright:: Copyright (c) 2013-2014 Chef Software, Inc.
# Copyright:: Copyright (c) 2016 GitLab B.V.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name 'python3'
default_version '3.4.8'

dependency 'libedit'
dependency 'ncurses'
dependency 'zlib'
dependency 'openssl'
dependency 'bzip2'

license 'Python-2.0'
license_file 'LICENSE'

source url: "https://python.org/ftp/python/#{version}/Python-#{version}.tgz",
       sha256: '8b1a1ce043e132082d29a5d09f2841f193c77b631282a82f98895a5dbaba1639'

relative_path "Python-#{version}"

LIB_PATH = %W(#{install_dir}/embedded/lib #{install_dir}/embedded/lib64 #{install_dir}/lib #{install_dir}/lib64 #{install_dir}/libexec).freeze

env = {
  'CFLAGS' => "-I#{install_dir}/embedded/include -O3 -g -pipe",
  'LDFLAGS' => "-Wl,-rpath,#{LIB_PATH.join(',-rpath,')} -L#{LIB_PATH.join(' -L')} -I#{install_dir}/embedded/include"
}

build do
  # Patches below are based on patches provided by martin.panter, 2016-06-02 06:31
  # in https://bugs.python.org/issue13501
  patch source: 'configure.ac.patch', target: "configure.ac"
  patch source: 'configure.patch', target: "configure"
  patch source: 'pyconfig.h.in.patch', target: "pyconfig.h.in"
  patch source: 'readline.c.patch', target: "Modules/readline.c"
  patch source: 'setup.py.patch', target: "setup.py"

  command ['./configure',
           "--prefix=#{install_dir}/embedded",
           '--enable-shared',
           '--with-readline=editline',
           '--with-dbmliborder='].join(' '), env: env
  make env: env
  make 'install', env: env

  delete("#{install_dir}/embedded/lib/python3.4/lib-dynload/dbm.*")
  delete("#{install_dir}/embedded/lib/python3.4/lib-dynload/_sqlite3.*")
  delete("#{install_dir}/embedded/lib/python3.4/test")
  command "find #{install_dir}/embedded/lib/python3.4 -name '__pycache__' -type d -print -exec rm -r {} +"
end

project.exclude "embedded/bin/python3*-config"
