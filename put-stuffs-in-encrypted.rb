#!/usr/bin/ruby

# 2004-12-25 - memastikan bahwa apa yg harus diencrypt (karena
# sifatnya private/rahasia) harus ditaruh di /encrypted.

LOG_LEVEL = 3
VERBOSE = 0
OVERWRITE = 1 # when both exist, delete stuff in /encrypted/ and move the unencrypted to encrypted

require 'pathname'
require 'fileutils'

# mv -nya gak berjalan dengan benar? atau gw harusnya pake mv FILE
# /OTHER/FILE instead of just mv FILE /OTHER/ ?
#include FileUtils

class String
  def escapeshellarg
    "'" + (self.gsub(/'/) {|s| "'"+'"'+"'"+'"'+"'"}) + "'"
  end

  alias_method :esc, :escapeshellarg
end

module Kernel
  alias_method :orig_system, :system

  def system(cmd, *args)
    puts "system: #{cmd} #{args.join ' '}"
    orig_system(cmd, *args) # or raise SystemCommandError, "#{$?}"
  end
end

def verbose1(msg); puts "VERBOSE1: "+msg if VERBOSE >= 1 end

def debug(msg); puts "DEBUG: "+msg if LOG_LEVEL >= 5 end
def info (msg); puts "INFO: " +msg if LOG_LEVEL >= 4 end
def warn (msg); puts "WARN: " +msg if LOG_LEVEL >= 3 end
def error(msg); puts "ERROR: "+msg if LOG_LEVEL >= 2 end
def fatal(msg); puts "FATAL: "+msg if LOG_LEVEL >= 1; exit 1 end

def realpath(p)
  Pathname.new(p).realpath.to_s
end

def basename(p)
  Pathname.new(p).basename.to_s
end

def dirname(p)
  Pathname.new(p).dirname.to_s
end

def in_encrypted(p)
  rp = realpath(p)
  result = rp =~ %r(^/encrypted/) ? true : false
  debug "in_encrypted: p=#{p}, realpath(p)=#{rp}, result=#{result}"
  result
end

# move /some/path to /encrypted/some/path and make /some/path symlink
# to /encrypted/some/path

def move_dir_to_encrypted(dir)
  verbose1 "Processing directory: #{dir}..."
  targetparentdir = "/encrypted#{dirname dir}"

  unless dir =~ %r(^/)
    error "INTERNAL ERROR: #{dir} doesn't start with a slash, skipped. " +
      "Please check my source code for errors."
    return
  end
  if dir =~ %r(/$)
    error "INTERNAL ERROR: #{dir} ends with, skipped. " +
      "Please check my source code for errors."
    return
  end
  if !FileTest.exists?(dir) && !FileTest.exists?("/encrypted#{dir}")
    warn "Both #{dir} and /encrypted#{dir} don't exist, skipped"
    return
  end
  if FileTest.exists?(dir) && !FileTest.directory?(dir)
    error "#{dir} is not a directory, skipped"
    return
  end

  if FileTest.symlink?(dir) && in_encrypted(File.readlink(dir))
    info "#{dir} is already symlinked to /encrypted, skipped"
    return
  end
  if (FileTest.exists?(dir) && !in_encrypted(dir))
    info "#{dir} is not in /encrypted, moving..."
    if FileTest.exists? "/encrypted#{dir}"
      if OVERWRITE
        system "rm -rf /encrypted#{dir}"
      else
        warn "/encrypted#{dir} and #{dir} exist, skipped. " +
          "You should probably delete #{dir} first."
        return
      end
    end
    system "mkdir -p #{targetparentdir.esc}"
    system "mv #{dir.esc} #{targetparentdir.esc}/"
  end

  if FileTest.exists?(dir) || !FileTest.exists?("/encrypted#{dir}")
    error "#{dir} still exists or /encrypted#{dir} doesn't exist, skipped. " +
      "You should probably check this situation."
    return
  end

  system %Q(ln -s #{"/encrypted#{dir}".esc} #{dir.esc})
end

def move_file_to_encrypted(file)
  verbose1 "Processing file: #{file}..."
  targetparentdir = "/encrypted#{dirname file}"

  unless file =~ %r(^/)
    error "INTERNAL ERROR: #{file} doesn't start with a slash, skipped. " +
      "Please check my source code for errors."
    return
  end
  if file =~ %r(/$)
    error "INTERNAL ERROR: #{file} ends with, skipped. " +
      "Please check my source code for errors."
    return
  end
  if !FileTest.exists?(file) && !FileTest.exists?("/encrypted#{file}")
    warn "Both #{file} and /encrypted#{file} don't exist, skipped"
    return
  end
  if FileTest.exists?(file) && FileTest.directory?(file)
    error "#{file} is a directory, skipped"
    return
  end

  if FileTest.symlink?(file) && in_encrypted(File.readlink(file))
    info "#{file} is already symlinked to /encrypted, skipped"
    return
  end
  if (FileTest.exists?(file) && !in_encrypted(file))
    info "#{file} is not in /encrypted, moving..."
    if FileTest.exists? "/encrypted#{file}"
      if OVERWRITE
        system "rm -f /encrypted#{file}"
      else
        warn "/encrypted#{file} and #{file} exist, skipped. " +
          "You should probably delete #{file} first."
        return
      end
    end
    system "mkdir -p #{targetparentdir.esc}"
    system "mv #{file.esc} #{targetparentdir.esc}"
  end

  if FileTest.exists?(file) || !FileTest.exists?("/encrypted#{file}")
    error "#{file} still exists or /encrypted#{file} doesn't exist, skipped. " +
      "You should probably check this situation."
    return
  end

  system %Q(ln -s #{"/encrypted#{file}".esc} #{file.esc})
end

# --- main

fatal "/encrypted is not mounted" unless 
  %x(/bin/mount) =~ %r(/dev/mapper/.+ on /encrypted)

raise RunTimeError, "Please run me as root" unless
  Process.uid == 0

# home dirs
move_dir_to_encrypted "/home/sloki/user/steven/home"
move_dir_to_encrypted "/home/sloki/user/steven/sites/steven.builder.localdomain/syslog"
move_dir_to_encrypted "/home/sloki/user/steven/sites/traps.steven.builder.localdomain/syslog"
move_dir_to_encrypted "/home/sloki/user/v/home"
move_dir_to_encrypted "/home/sloki/user/v2/home"
move_dir_to_encrypted "/home/sloki/user/v3/home"
move_dir_to_encrypted "/home/sloki/user/slk/home"

# /root
move_dir_to_encrypted "/root/Desktop"
# -- all dotfiles
Dir.chdir "/root"
dirs = []; files = []
Dir[".*"].each {|e|
  next if e == '.' || e == '..'
  (FileTest.directory?(e) ? dirs : files) << "/root/#{e}"
}
dirs.each  {|d| move_dir_to_encrypted d}
files.each {|f| move_file_to_encrypted f}

# squid
move_dir_to_encrypted "/var/log/squid"
move_dir_to_encrypted "/var/spool/squid"

# slocate
#move_dir_to_encrypted "/var/cache/locate" # ini kalau belum instal paket 'slocate'
move_dir_to_encrypted "/var/lib/slocate"

# ftp
Dir["/var/log/xferlog*"].each { |f| move_file_to_encrypted f }

# samba
move_dir_to_encrypted "/var/log/samba"

# XXX steven's apache log of steven.builder.localdomain, traps.steven.builder.localdomain

# XXX slk-smtpd's logs? (/var/log/slk-smtpd and
# /var/spool/slk-smtpd). in the mean time, ngirim email private pakai
# web saja...

# NOTE: /e/usr/bin/manipurlation gak ada symlinknya

# dnscache & tinydns
move_dir_to_encrypted "/etc/dnscache/log"
move_dir_to_encrypted "/etc/tinydns/log"
