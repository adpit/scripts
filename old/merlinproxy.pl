#!/usr/bin/env perl -Tw
use strict;
$ENV{PATH} = join ":", qw(/usr/ucb /bin /usr/bin);
$|++;

## Copyright (c) 1996 by Randal L. Schwartz
## This program is free software; you can redistribute it
## and/or modify it under the same terms as Perl itself.

## Anonymous HTTP proxy (handles http:, gopher:, ftp:)
## requires LWP 5.04 or later

my $HOST = "localhost";
my $PORT = "8082";

sub prefix {
  my $now = localtime;

  join "", map { "[$now] [${$}] $_\n" } split /\n/, join "", @_;
}

$SIG{__WARN__} = sub { warn prefix @_ };
$SIG{__DIE__} = sub { die prefix @_ };
$SIG{CLD} = $SIG{CHLD} = sub { wait; };

my $AGENT;                      # global user agent (for efficiency)
BEGIN {
  use LWP::UserAgent;

  @MyAgent::ISA = qw(LWP::UserAgent); # set inheritance

  $AGENT = MyAgent->new;
  $AGENT->agent("anon/0.07");
  $AGENT->env_proxy;
}

sub MyAgent::redirect_ok { 0 } # redirects should pass through

{                               ### MAIN ###
  use HTTP::Daemon;

  my $master = new HTTP::Daemon
    ReuseAddr => 1, 
    LocalAddr => $HOST, LocalPort => $PORT;
  warn "set your proxy to <URL:", $master->url, ">";
  my $slave;
  &handle_connection($slave) while $slave = $master->accept;
  exit 0;
}                               ### END MAIN ###

sub handle_connection {
  my $connection = shift;       # HTTP::Daemon::ClientConn

  my $pid = fork;
  if ($pid) {                   # spawn OK, and I'm the parent
    close $connection;
    return;
  }
  ## spawn failed, or I'm a good child
  my $request = $connection->get_request;
  if (defined($request)) {
    my $response = &fetch_request($request);
    $connection->send_response($response);
    close $connection;
  }
  exit 0 if defined $pid;       # exit if I'm a good child with a good parent
}

sub fetch_request {
  my $request = shift;          # HTTP::Request

  use HTTP::Response;

  my $url = $request->url;
  warn "fetching $url";
  if ($url->scheme !~ /^(http|gopher|ftp)$/) {
    my $res = HTTP::Response->new(403, "Forbidden");
    $res->content("bad scheme: @{[$url->scheme]}\n");
    $res;
  } elsif (not $url->rel->netloc) {
    my $res = HTTP::Response->new(403, "Forbidden");
    $res->content("relative URL not permitted\n");
    $res;
  } else {
    &fetch_validated_request($request);
  }
}

sub fetch_validated_request { # return HTTP::Response
  my $request = shift;  # HTTP::Request

  ## uses global $AGENT

  ## warn "orig request: <<<", $request->headers_as_string, ">>>";
  $request->remove_header(qw(User-Agent From Referer Cookie));
  ## warn "anon request: <<<", $request->headers_as_string, ">>>";
  my $response = $AGENT->request($request);
  ## warn "orig response: <<<", $response->headers_as_string, ">>>";
  $response->remove_header(qw(Set-Cookie));
  ## warn "anon response: <<<", $response->headers_as_string, ">>>";
  $response;
}
