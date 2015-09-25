use Config;

BEGIN {
    my $can_fork = $Config{d_fork} ||
		    (($^O eq 'MSWin32' || $^O eq 'NetWare') and
		     $Config{useithreads} and 
		     $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/
		    );
    my $reason;
    if ($ENV{PERL_CORE} and $Config{'extensions'} !~ /\bSocket\b/) {
	$reason = 'Socket extension unavailable';
    }
    elsif ($ENV{PERL_CORE} and $Config{'extensions'} !~ /\bIO\b/) {
	$reason = 'IO extension unavailable';
    }
    elsif (!$can_fork) {
        $reason = 'no fork';
    }
    if ($reason) {
	print "1..0 # Skip: $reason\n";
	exit 0;
    }
}

my $TimeoutRead = 5;
my $TimeoutWrite = 5;

my $has_perlio = $] >= 5.008 && find PerlIO::Layer 'perlio';

$| = 1;
print "1..13\n";

eval {
    $SIG{ALRM} = sub { die; };
    alarm 120;
};

use IO::Socket; # for AF_INET
use IO::Socket::Timeout;

$listen = IO::Socket::INET->new(Listen => 2,
				Proto => 'tcp',
				# some systems seem to need as much as 10,
				# so be generous with the timeout
				Timeout => 15,
			       ) or die "$!";
IO::Socket::Timeout->enable_timeouts_on($listen);
$listen->read_timeout($TimeoutRead);
$listen->write_timeout($TimeoutWrite);

print "ok 1\n";

# Check if can fork with dynamic extensions (bug in CRT):
if ($^O eq 'os2' and
    system "$^X -I../lib -MOpcode -e 'defined fork or die'  > /dev/null 2>&1") {
    print "ok $_ # skipped: broken fork\n" for 2..5;
    exit 0;
}

$port = $listen->sockport;

# Test various other ways to create INET sockets that should
# also work.
$listen = IO::Socket::INET->new(Listen => '', Timeout => 15, ) or die "$!";
IO::Socket::Timeout->enable_timeouts_on($listen);
$listen->read_timeout($TimeoutRead);
$listen->write_timeout($TimeoutWrite);
$port = $listen->sockport;

if($pid = fork()) {
  SERVER_LOOP:
    while (1) {
       last SERVER_LOOP unless $sock = $listen->accept;
       while (<$sock>) {
           last SERVER_LOOP if /^quit/;
           last if /^done/;
           print;
       }
       $sock = undef;
    }
    $listen->close;
} elsif (defined $pid) {
    # child, try various ways to connect
    $sock = IO::Socket::INET->new("localhost:$port")
         || IO::Socket::INET->new("127.0.0.1:$port");
    IO::Socket::Timeout->enable_timeouts_on($sock);
    if ($sock) {
	print "not " unless $sock->connected;
	print "ok 2\n";
       $sock->print("ok 3\n");
       sleep(1);
       print "ok 4\n";
       $sock->print("ok 5\n");
       $sock->print("done\n");
       $sock->close;
    }
    else {
	print "# $@\n";
	print "not ok 2\n";
	print "not ok 3\n";
	print "not ok 4\n";
	print "not ok 5\n";
    }

    # some machines seem to suffer from a race condition here
    sleep(2);

    $sock = IO::Socket::INET->new("127.0.0.1:$port");
    IO::Socket::Timeout->enable_timeouts_on($sock);
    if ($sock) {
       $sock->print("ok 6\n");
       $sock->print("done\n");
       $sock->close;
    }
    else {
	print "# $@\n";
	print "not ok 6\n";
    }

    # some machines seem to suffer from a race condition here
    sleep(1);

    $sock = IO::Socket->new(Domain => AF_INET,
                            PeerAddr => "localhost:$port")
         || IO::Socket->new(Domain => AF_INET,
                            PeerAddr => "127.0.0.1:$port");
    IO::Socket::Timeout->enable_timeouts_on($sock);
    if ($sock) {
       $sock->print("ok 7\n");
       $sock->print("quit\n");
    } else {
       print "not ok 7\n";
    }
    $sock = undef;
    sleep(1);
    exit;
} else {
    die;
}

# Then test UDP sockets
$server = IO::Socket->new(Domain => AF_INET,
                          Proto  => 'udp',
                          LocalAddr => 'localhost')
       || IO::Socket->new(Domain => AF_INET,
                          Proto  => 'udp',
                          LocalAddr => '127.0.0.1');
IO::Socket::Timeout->enable_timeouts_on($server);
$server->read_timeout($TimeoutRead);
$server->write_timeout($TimeoutWrite);
$port = $server->sockport;

if ($pid = fork()) {
    my $buf;
    $server->recv($buf, 100);
    print $buf;
} elsif (defined($pid)) {
    #child
    $sock = IO::Socket::INET->new(Proto => 'udp',
                                  PeerAddr => "localhost:$port")
         || IO::Socket::INET->new(Proto => 'udp',
                                  PeerAddr => "127.0.0.1:$port");
    IO::Socket::Timeout->enable_timeouts_on($sock);
    $sock->read_timeout($TimeoutRead);
    $sock->write_timeout($TimeoutWrite);
    $sock->send("ok 8\n");
    sleep(1);
    $sock->send("ok 8\n");  # send another one to be sure
    exit;
} else {
    die;
}

print "not " unless $server->blocking;
print "ok 9\n";

if ( $^O eq 'qnx' ) {
  # QNX4 library bug: Can set non-blocking on socket, but
  # cannot return that status.
  print "ok 10 # skipped on QNX4\n";
} else {
  $server->blocking(0);
  print "not " if $server->blocking;
  print "ok 10\n";
}

### TEST 15
### Set up some data to be transfered between the server and
### the client. We'll use own source code ...
#
local @data;
if( !open( SRC, "< $0")) {
    print "not ok 11 - $!\n";
} else {
    @data = <SRC>;
    close(SRC);
    print "ok 11\n";
}

# test Blocking option in constructor

$sock = IO::Socket::INET->new(Blocking => 0)
    or print "not ";
IO::Socket::Timeout->enable_timeouts_on($sock);
$sock->read_timeout($TimeoutRead);
$sock->write_timeout($TimeoutWrite);
print "ok 12\n";

if ( $^O eq 'qnx' ) {
  print "ok 13 # skipped on QNX4\n";
  # QNX4 library bug: Can set non-blocking on socket, but
  # cannot return that status.
} else {
  my $status = $sock->blocking;
  print "not " unless defined $status && !$status;
  print "ok 13\n";
}
