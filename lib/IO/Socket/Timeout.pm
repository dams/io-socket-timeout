package IO::Socket::Timeout;

use strict;
use warnings;
use PerlIO::via::TimeoutWithReset;
use Role::Tiny;

use Carp;


# ABSTRACT: IO::Socket with read/write timeout

=head1 DESCRIPTION

C<IO::Socket> provides a way to set a timeout on the socket, but the timeout
will be used only for connection, not for reading / writing operations.

This module provides a way to set a timeout on read / write operations on an
C<IO::Socket> instance, or any C<IO::Socket::*> modules, like
C<IO::Socket::INET>.

=head1 SYNOPSIS

  use IO::Socket::With::Timeout;

  # creates a IO::Socket::INET::With::Timeout object
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     # other standard arguments );

  my $socket = IO::Socket::UNIX->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     WriteTimeout => 0.5,
                                                     # other standard arguments );

  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadWriteTimeout => 0.5,
                                                     # other standard arguments );

  # When using the socket:
  use Errno qw(ETIMEDOUT);
  print $socket $request;
  my $response = <$socket>;
  if (!defined $response && 0+$! == ETIMEDOUT) {
    die "timeout reading on the socket";
  }

=head1 CONSTRUCTORS

=head2 new::with::timeout

To be able to work with any class that is or inherits from IO::Socket, the
interface of this module is a bit unusual.

C<IO::Socket::INET->new::with::timeout(...)> will return an instance of
C<IO::Socket::INET>, as if it had been called with
C<IO::Socket::INET->new(...)>. However, it'll apply some mechanism on the
resulting socket object so that it times out on read, write, or both.

The way the socket will timeout ( on connection, read, write, how long), can be
specified with these parameters:

=over

=item Timeout

This is the default parameter that already exists in IO::Socket. If set to a
value, the socket will timeout at B<connection time>.

=item ReadTimeout

If set to a value, the socket will timeout on reads. Value is in seconds, floats
accepted.

=item WriteTimeout

If set to a value, the socket will timeout on writes. Value is in seconds, floats
accepted.

=item ReadWriteTimeout

If set to a value, the socket will timeout on reads and writes. Value is in seconds, floats
accepted. If set, this option superseeds ReadTimeout and WriteTimeout.

=item WithSysTimeout

Defaults to 1. If set to a true value, C<sysread> and <syswrite> functions will
be subjects to the timeout as well. Otherwise they won't.

=back

=head2 socketpair::with::timeout

There is an other way to create sockets from scratch, via C<socketpair>. As for
the C<new> constructor, this module provides its counterpart with timeout
feature.

C<IO::Socket::INET->socketpair::with::timeout(...)> will return two instances of
C<IO::Socket::INET>, as if it had been called with
C<IO::Socket::INET->socketpair(...)>. However, it'll apply some mechanism on the
resulting socket object so that it times out on read, write, or both.

=head1 METHODS

=head2 read_timeout

  my $current_timeout = $socket->read_timeout();
  $socket->read_timeout($new_timeout);

=head2 write_timeout

  my $current_timeout = $socket->write_timeout();
  $socket->write_timeout($new_timeout);

=head2 enable_timeout

  $socket->enable_timeout;

=head2 disable_timeout

  $socket->disable_timeout;

=head2 timeout_enabled

  my $is_timeout_enabled = $socket->timeout_enabled();
  $socket->timeout_enabled(0);

=head2 enable_sys_timeout

  $socket->enable_sys_timeout;

=head2 disable_sys_timeout

  $socket->disable_sys_timeout;

=head2 sys_timeout_enabled

  my $is_sys_timeout_enabled = $socket->sys_timeout_enabled();
  $socket->sys_timeout_enabled(0);

=head1 CHANGE SETTINGS AFTER CREATION

You can change the timeout settings of a socket after it has been instanciated.

  use IO::Socket::With::Timeout;
  # create a socket with read timeout
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     # other standard arguments );

  use PerlIO::via::Timeout qw(:all);
  # change read_timeout to 5 and write timeout to 1.5 sec
  $socket->read_timeout(5)
  $socket->write_timeout(1.5)
  # actually disable the timeout for now
  $socket->disable_timeout()
  # when re-enabling it, timeouts value are restored
  $socket->enable_timeout()

=head1 WHEN TIMEOUT IS HIT

When a timeout (read, write) is hit on the socket, the function trying to be
performed will return C<undef>, and C<$!> will be set to C<ETIMEOUT>.

The socket will be marked as invalid internally, and any subsequential use of
it will return C<undef>, and C<$!> will be set to C<ECONNRESET>.

Why invalid the socket ? If you read a socket, waiting for message A, and hit a
timeout, if you then reuse the socket to read a message B, you might receive
the answer A instead. There is no way to properly discard the first message,
because the sender mught not be reachable (that's probably why you got a
timeout in the first place). So after a timeout failure, it's important that
you recreate the socket.

You can import C<ETIMEOUT> and C<ECONNRESET> by using C<POSIX>:

  use Errno qw(ETIMEDOUT ECONNRESET);

=head1 IF YOU NEED TO RETRY

If you want to implement a try / wait / retry mechanism, I recommend using a
third-party module, like C<Action::Retry>. Something like this:

  my $socket;

  my $answer;
  my $action = Action::Retry->new(
    attempt_code => sub {
        # (re-)create the socket if needed
        $socket && ! $socket->error
          or $socket = IO::Socket->new::with::timeout(ReadTimeout => 0.5);
        # send the request, read the answer
        $socket->print($_[0]);
        defined($answer = $socket->getline) or die $!;
        $answer;
    },
    on_failure_code => sub { die 'aborting, to many retries' },
  );

  my $reply = $action->run('GET mykey');

=head1 SEE ALSO

L<Action::Retry>, L<IO::Select>, L<PerlIO::via::Timeout>, L<Time::Out>

=head1 THANKS

Thanks to Vincent Pitt, Christian Hansen and Toby Inkster for various help and
useful remarks.

=cut

our $DEFAULT_STRATEGY = 'Select';

sub new::with::timeout {
    my $class = shift
      or croak "needs a class name. Try IO::Socket::INET->new::with::timeout(...)";

    my $class_file = $class;
    $class_file =~ s!::|'!/!g;
    $class_file .= '.pm';
    require $class_file;

    $class->isa('IO::Socket')
      or croak 'new::with::timeout can be used only on classes that isa IO::Socket';

    # if arguments are not key values, just original class constructor
    @_ % 2
      and return $class->new(@_);

    my %args = @_;

    my $read_timeout = delete $args{ReadTimeout};
    my $write_timeout = delete $args{WriteTimeout};
    if (defined (my $readwrite_timeout = delete $args{ReadWriteTimeout})) {
        $read_timeout = $write_timeout = $readwrite_timeout;
    }
    
    # by default we timeout on sysread/syswrite as well
    my $with_sys_timeout = defined $args{WithSysTimeout} ? delete $args{WithSysTimeout} : 1;

    # if no timeout feature is used, just call original class constructor
    $read_timeout && $read_timeout > 0 || $write_timeout && $write_timeout > 0
      or return $class->new(%args);

    my $socket = $class->new(%args)
      or return;

    binmode($socket, ':via(TimeoutWithReset)');

    Role::Tiny->apply_roles_to_object($socket, qw(IO::Socket::Timeout::Role::SysTimeout));

    $read_timeout && $read_timeout > 0
      and $socket->read_timeout($read_timeout);
    $write_timeout && $write_timeout > 0
      and $socket->write_timeout($write_timeout);
    $socket->sys_timeout_enabled($with_sys_timeout);

    return $socket;
}

sub socketpair::with::timeout {
    my $class = shift
      or croak "needs a class name. Try IO::Socket::INET->socketpair::with::timeout(...)";

    my $class_file = $class;
    $class_file =~ s!::|'!/!g;
    $class_file .= '.pm';
    require $class_file;

    $class->isa('IO::Socket')
      or croak 'new::with::timeout can be used only on classes that isa IO::Socket';

    # we expect DOMAIN, TYPE, PROTOCOL, TIMEOUT_ARGS. Otherwise just call original
    @_ == 4
      or return $class->socketpair(@_);

    my $timeout_args = pop;

    my %args = %$timeout_args;
    my $read_timeout = delete $args{ReadTimeout};
    my $write_timeout = delete $args{WriteTimeout};
    if (defined (my $readwrite_timeout = delete $args{ReadWriteTimeout})) {
        $read_timeout = $write_timeout = $readwrite_timeout;
    }

    # by default we timeout on sysread/syswrite as well
    my $with_sys_timeout = defined $args{WithSysTimeout} ? delete $args{WithSysTimeout} : 1;

    # if no timeout feature is used, just call original class constructor
    $read_timeout && $read_timeout > 0 || $write_timeout && $write_timeout > 0
      or return $class->socketpair(%args);

    my ($socket1, $socket2) = $class->socketpair(%args)
       or return;

    foreach my $socket ($socket1, $socket2) {
        binmode($socket, ':via(TimeoutWithReset)');
        Role::Tiny->apply_roles_to_object($socket, qw(IO::Socket::Timeout::Role::SysTimeout));
        $read_timeout && $read_timeout > 0
          and $socket->read_timeout($read_timeout);
        $write_timeout && $write_timeout > 0
          and $socket->write_timeout($write_timeout);
        $socket->sys_timeout_enabled($with_sys_timeout);
    }
    return ($socket1, $socket2);
}

# sysread FILEHANDLE,SCALAR,LENGTH,OFFSET
BEGIN {
    my $_no_wrapping;
    *CORE::GLOBAL::sysread = sub {
        $_no_wrapping || ! PerlIO::via::Timeout->_fh2prop($_[0])->{sys_timeout_enabled}
          and return CORE::sysread($_[0], $_[1], $_[2]);

        $_no_wrapping = 1;
        my $ret_val = PerlIO::via::TimeoutWithReset->READ($_[1], $_[2], $_[0]);
        $_no_wrapping = 0;
        return $ret_val;
    }
}

# syswrite FILEHANDLE,SCALAR,LENGTH,OFFSET
BEGIN {
    my $_no_wrapping;
    *CORE::GLOBAL::syswrite = sub {
        $_no_wrapping || ! PerlIO::via::Timeout->_fh2prop($_[0])->{sys_timeout_enabled}
          and return CORE::syswrite($_[0], $_[1], $_[2]);

        $_no_wrapping = 1;
        my $ret_val = PerlIO::via::TimeoutWithReset->WRITE($_[1], $_[0]);
        $_no_wrapping = 0;
        return $ret_val;
    }
}

package IO::Socket::Timeout::Role::SysTimeout;
use Role::Tiny;
use PerlIO::via::Timeout;

sub read_timeout    { goto &PerlIO::via::Timeout::read_timeout    }
sub write_timeout   { goto &PerlIO::via::Timeout::write_timeout   }
sub enable_timeout  { goto &PerlIO::via::Timeout::enable_timeout  }
sub disable_timeout { goto &PerlIO::via::Timeout::disable_timeout }
sub timeout_enabled { goto &PerlIO::via::Timeout::timeout_enabled }

sub enable_sys_timeout  { $_[0]->sys_timeout_enabled(1) }
sub disable_sys_timeout { $_[0]->sys_timeout_enabled(0) }
sub sys_timeout_enabled {
    @_ > 1 and PerlIO::via::Timeout->_fh2prop($_[0])->{sys_timeout_enabled} = !!$_[1];
    PerlIO::via::Timeout->_fh2prop($_[0])->{sys_timeout_enabled};
}

1;
