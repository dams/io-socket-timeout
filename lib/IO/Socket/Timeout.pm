package IO::Socket::Timeout;

use strict;
use warnings;

use PerlIO::via::Timeout qw(timeout_strategy);

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
                                                     TimeoutStrategy => 'Alarm',
                                                     # other standard arguments );

  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadWriteTimeout => 0.5,
                                                     TimeoutStrategy => '+My::Own::Strategy',
                                                     # other standard arguments );

  # When using the socket:
  use Errno qw(ETIMEDOUT);
  print $socket $request;
  my $response = <$socket>;
  if (!defined $response && 0+$! == ETIMEDOUT) {
    die "timeout reading on the socket";
  }

  # You can change the default strategy that will be used, if possible.
  use IO::Socket::With::Timeout default_strategy => Select;

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

=item TimeoutStrategy

Used to specify the timeout implementation used. The value should be a module
name. If it B<doesn't> start with C<+>, the value will be prepended with
C<PerlIO::via::Timeout::Strategy::>. If it B<does> start with C<+>, the value is
expected to be the fullname of a module. The default value is C<'SetSockOpt'>
unless the detected Operating System is NetBSD or Solaris, in which case it'll
use C<SelectWithReset> instead. See L<PerlIO::via::Timeout::Strategy::SetSockOpt> for
instance.

To get a list of available strategy, see below (L<AVAILABLE STRATEGIES>).

=back

=head2 socketpair::with::timeout

There is an other way to create sockets from scratch, via C<socketpair>. As for
the C<new> constructor, this module provides its counterpart with timeout
feature.

C<IO::Socket::INET->socketpair::with::timeout(...)> will return two instances of
C<IO::Socket::INET>, as if it had been called with
C<IO::Socket::INET->socketpair(...)>. However, it'll apply some mechanism on the
resulting socket object so that it times out on read, write, or both.

=head1 FINE-TUNING

If you need to alter the behavior of the socket after it has been created, you
can access its strategy and fiddle with it, using PerlIO::via::Timeout.

  use IO::Socket::With::Timeout;
  # create a socket with read timeout
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     ReadTimeout => 0.5,
                                                     # other standard arguments );
  use PerlIO::via::Timeout qw(timeout_strategy);
  # use PerlIO::via::Timeout to retrieve the strategy
  my stratefy = timeout_strategy($sock);
  # change read_timeout to 5 and write timeout to 1.5 sec
  $strategy->read_timeout(5)
  $strategy->write_timeout(1.5)
  # actually disable the timeout for now
  $strategy->disable_timeout()
  # when re-enabling it, timeouts value are restored
  $strategy->enable_timeout()

See L<PerlIO::via::Timeout> for more details

=head1 WHEN TIMEOUT IS HIT

When a timeout (read, write) is hit on the socket, the function trying to be
performed will return C<undef>, and C<$!> will be set to C<ETIMEOUT>.

The socket will be marked as invalid internally, and any subsequential use of
it will return C<undef>, and $! will be set to C<ECONNRESET>.

Why invalid the socket ? If you read a socket, waiting for message A, and hit a
timeout, if you then reuse the socket to read a message B, you might receive
the answer A instead. There is no way to properly discard the first message,
because the sender mught not be reachable (that's probably why you got a
timeout in the first place). So after a timeout failure, it's important that
you recreate the socket.

You can import ETIMEOUT and ECONNRESET by using C<POSIX>:

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

=head1 AVAILABLE STRATEGIES

Here is a list of strategies to be used. You can create your own (see below).

=head2 SetSockOpt

Doesn't work on Solaris and NetBSD.

This strategy sets appropriate read / write options on the socket, to have a
proper timeout. This is probably the most efficient and precise way of setting
up a timeout.

It makes sure the socket can't be used once the timeout has
been hit, by returning undef and setting C<$!> to C<ECONNRESET>.

See L<PerlIO::via::Timeout::Strategy::SetSockOpt>.

=head2 SelectWithReset

Uses C<select>.

It makes sure the socket can't be used once the timeout has been hit, by
returning undef and setting C<$!> to C<ECONNRESET>.

See L<PerlIO::via::Timeout::Strategy::SelectWithReset>.

=head2 AlarmWithReset

Doesn't work on Win32. Uses C<Time::Out> (which uses C<alarm> internally).

It makes sure the socket can't be used once the timeout has been hit, by
returning undef and setting C<$!> to C<ECONNRESET>.

See L<PerlIO::via::Timeout::Strategy::AlarmWithReset>.

=head1 DEFAULT STRATEGY

When nothing is specified, IO::Socket::Timeout will use the C<SetSockOpt>
strategy by default, unless the detected Operating System is NetBSD or Solaris.
In which case it'll use C<SelectWithReset> instead.

you can override the default strategy being used using one of these ways:

=over

=item import option

  # this will setup the Alarm strategy by default
  use IO::Socket::Timeout default_strategy => 'Alarm';

  # same, but at runtime
  require IO::Socket::Timeout;
  IO::Socket::Timeout->import(default_strategy => 'Alarm');

  # you can also use your own strategy as default
  use IO::Socket::Timeout default_strategy => '+My::Strategie';

=item configuration variable

  $IO::Socket::Timeout::DEFAULT_STRATEGY = 'Alarm';

=back

=head1 CREATE YOUR OWN STRATEGY


=head1 SEE ALSO

L<Action::Retry>, L<IO::Select>, L<PerlIO::via::Timeout>, L<Time::Out>

=head1 THANKS

The author would like to thank Toby Inkster, Vincent Pitt for various helps and
useful remarks.

=cut

our %TIMEOUT_CLASS;
our $DEFAULT_STRATEGY = $^O ne 'netbsd' && $^O ne 'solaris' ? 'SetSockOpt' : 'Select';


sub import {
    my ($package, %args) = @_;
    $DEFAULT_STRATEGY = $args{default_strategy} || $DEFAULT_STRATEGY;
}

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

    binmode($socket, ':via(Timeout)');
    timeout_strategy( $socket, $args{TimeoutStrategy} || $DEFAULT_STRATEGY,
                      read_timeout => $read_timeout,
                      write_timeout => $write_timeout
                    );
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
        binmode($socket, ':via(Timeout)');
        timeout_strategy( $socket, $args{TimeoutStrategy} || $DEFAULT_STRATEGY,
                          read_timeout => $read_timeout,
                          write_timeout => $write_timeout
                        );
    }
    return ($socket1, $socket2);
}

1;
