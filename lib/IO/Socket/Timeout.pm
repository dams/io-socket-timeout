package IO::Socket::Timeout;

use strict;
use warnings;
use PerlIO::via::TimeoutWithReset;
use PerlIO::via::Timeout qw(:all);

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

=back

=head2 socketpair::with::timeout

There is an other way to create sockets from scratch, via C<socketpair>. As for
the C<new> constructor, this module provides its counterpart with timeout
feature.

C<IO::Socket::INET->socketpair::with::timeout(...)> will return two instances of
C<IO::Socket::INET>, as if it had been called with
C<IO::Socket::INET->socketpair(...)>. However, it'll apply some mechanism on the
resulting socket object so that it times out on read, write, or both.

=head1 CHANGE SETTINGS AFTER CREATION

You can change the timeout settings of a socket after it has been instanciated.
These functions are part of L<PerlIO::via::Timeout>. Check its documentation
for more details.

  use IO::Socket::With::Timeout;
  # create a socket with read timeout
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     # other standard arguments );

  use PerlIO::via::Timeout qw(:all);
  # change read_timeout to 5 and write timeout to 1.5 sec
  read_timeout($socket, 5)
  write_timeout($socket, 1.5)
  # actually disable the timeout for now
  disable_timeout($socket)
  # when re-enabling it, timeouts value are restored
  enable_timeout($socket)

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
    
    # if no timeout feature is used, just call original class constructor
    $read_timeout && $read_timeout > 0 || $write_timeout && $write_timeout > 0
      or return $class->new(%args);

    my $socket = $class->new(%args);

    binmode($socket, ':via(TimeoutWithReset)');
    $read_timeout && $read_timeout > 0
      and read_timeout($socket, $read_timeout);
    $write_timeout && $write_timeout > 0
      and write_timeout($socket, $write_timeout);
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

    # if no timeout feature is used, just call original class constructor
    $read_timeout && $read_timeout > 0 || $write_timeout && $write_timeout > 0
      or return $class->socketpair(@_);

    my ($socket1, $socket2) = $class->socketpair(@_)
       or return;


    foreach my $socket ($socket1, $socket2) {
        binmode($socket, ':via(TimeoutWithReset)');
        $read_timeout && $read_timeout > 0
          and read_timeout($socket, $read_timeout);
        $write_timeout && $write_timeout > 0
          and write_timeout($socket, $write_timeout);
    }
    return ($socket1, $socket2);
}

1;
