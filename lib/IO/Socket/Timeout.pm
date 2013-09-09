package IO::Socket::Timeout;

use strict;
use warnings;

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
                                                     TimeoutRead => 0.5,
                                                     # other standard arguments );

  my $socket = IO::Socket::UNIX->new::with::timeout( Timeout => 2,
                                                     TimeoutRead => 0.5,
                                                     TimeoutWrite => 0.5,
                                                     # other standard arguments );

  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     TimeoutReadWrite => 0.5,
                                                     TimeoutStrategy => 'Alarm',
                                                     # other standard arguments );

  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 2,
                                                     TimeoutReadWrite => 0.5,
                                                     TimeoutStrategy => '+My::Own::Strategy',
                                                     # other standard arguments );

  # When using the socket:
  $socket->print($request);
  my $response = $socket->getline;
  if (!defined $response && $! eq 'Operation timed out') {
    die "timeout reading on the socket";
  }

  # You can change the default strategy that will be used, if possible.
  use IO::Socket::With::Timeout default_strategy => Select;

=head1 CONSTRUCTOR

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
value, the socket will timeout at connection time by default.

=item TimeoutRead

If set to a value, the socket will timeout on reads. Value is in seconds, floats
accepted.

=item TimeoutWrite

If set to a value, the socket will timeout on writes. Value is in seconds, floats
accepted.

=item TimeoutStrategy

Used to specify the timeout implementation used. The value should be a module
name. If it B<doesn't> start with C<+>, the value will be prepended with
C<IO::Socket::Timeout::Strategy::>. If it B<does> start with C<+>, the value is
expected to be the fullname of a module. The default value is C<'Select'>.

=back

=head1 WHEN TIMEOUT IS HIT

When a timeout (read, write) is hit on the socket, the function trying to be
performed will return C<undef> (actually an empty list), the socket will be
closed, and C<$!> will be set to C<ETIMEOUT>.

The socket wil be B<closed> and marked as invalid internally, and any
subsequential use of it will return C<undef>, and $! will be set to
C<ECONNRESET>.

Why close the socket ? If you read a socket, waiting for message A, and hit a
timeout, if you then reuse the socket to read a message B, you might receive
the answer A instead. There is no way to properly discard the first message,
because the sender mught not be reachable (that's probably why you got a
timeout in the first place). So after a timeout failure, it's important that
you recreate the socket.

You can import ETIMEOUT and ECONNRESET by using C<POSIX>:

  use POSIX qw(ETIMEDOUT ECONNRESET);

=head1 IF YOU NEED TO RETRY

I recommend using third-party module, like C<Action::Retry>. Something like
this:

  my $socket;

  my $answer;
  my $action = Action::Retry->new(
    attempt_code => sub {
        # (re-)create the socket if needed
        $socket && ! $socket->error
          or $socket = IO::Socket->new::with::timeout(TimeoutRead => 0.5);
        # send the request, read the answer
        $socket->print($_[0]);
        defined($answer = $socket->getline) or die $!;
        $answer;
    },
    on_failure_code => sub { die 'aborting, to many retries' },
  );

  my $val = $action->run('GET mykey');

=head1 AVAILABLE STRATEGIES

Here is a list of strategies to be used. You can create your own (see below).

=head2 SetSockOpt

Doesn't work on Solaris and NetBSD.

This strategy sets appropriate read / write options on the socket, to have a
proper timeout. This is probably the most efficient and precise way of setting
up a timeout.

=head2 Select

The default strategy. Uses C<IO::Select>

=head2 Alarm

Doesn't work on Win32. Uses C<Time::Out> (which uses C<alarm> internally)

=head1 DEFAULT STRATEGY

When nothing is specified, IO::Socket::Timeout will use the C<SetSockOpt>
strategy by default, unless the detected Operating System is NetBSD or Solaris.
In which case it'll use C<Select> instead.

you can override the default strategy being used using one of these ways:

=over

=item import option

  # this will setup the Alarm strategy by default
  use IO::Socket::Timeout default_strategy => 'Alarm';

  # same, but at runtime
  require IO::Socket::Timeout;
  IO::Socket::Timeout->import(default_strategy => 'Alarm');

=item configuration variable

  $IO::Socket::Timeout::DEFAULT_STRATEGY = 'Alarm';

=back

=head1 CREATE YOUR OWN STRATEGY

=head1 SEE ALSO

L<Action::Retry>, L<IO::Select>, L<Time::Out>

=cut

use Module::Load qw(load);

use Class::Method::Modifiers qw(install_modifier);

use Config;

our %TIMEOUT_CLASS;
our $DEFAULT_STRATEGY = $Config{osname} ne 'netbsd' && $Config{osname} ne 'solaris' ? 'SetSockOpt' : 'Select';


sub import {
    my ($package, %args) = @_;
    $DEFAULT_STRATEGY = $args{default_strategy} || $DEFAULT_STRATEGY;
}

sub new::with::timeout {
    my $class = shift
      or croak "needs a class name. Try IO::Socket::INET->new::with::timeout(...)";
    load $class;
    $class->isa('IO::Socket')
      or croak 'new::with::timeout can be used only on classes that isa IO::Socket';

    # if arguments are not key values, just original class constructor
    @_ % 2
      and return $class->new(@_);

    my %args = @_;
    my $timeout_read = delete $args{TimeoutRead};
    my $timeout_write = delete $args{TimeoutWrite};

    my $strategy = delete $args{TimeoutStrategy} || $DEFAULT_STRATEGY;
    index( $strategy, '+' ) == 0
      or $strategy = 'IO::Socket::Timeout::Strategy::' . $strategy;
    load $strategy;

    # if no timeout feature is used, just call original class constructor
    $timeout_read && $timeout_read > 0 || $timeout_write && $timeout_write > 0
      or return $class->new(%args);

    # create our derivated class
    my $class_with_timeout = $class . '__WITH__'
      . join('_AND_',
             'READ' x !!$timeout_read,
             'WRITE' x !!$timeout_write)
      . '__'
      . $strategy;

    if ( ! $TIMEOUT_CLASS{$class_with_timeout} ) {
        no strict 'refs';
        push @{"${class_with_timeout}::ISA"}, $class;
        $strategy->apply_to_class($class_with_timeout, $timeout_read, $timeout_write);
        $TIMEOUT_CLASS{$class_with_timeout} = 1;
    }

    my $instance = $class_with_timeout->new(%args);
    $strategy->apply_to_instance($instance, $class_with_timeout, $timeout_read, $timeout_write);
    $instance;

}

sub socketpair::with::timeout {
    my $class = shift
      or croak "needs a class name. Try IO::Socket::INET->socketpair::with::timeout(...)";
    load $class;
    $class->isa('IO::Socket')
      or croak 'socketpair::with::timeout can be used only on classes that isa IO::Socket';

    # DOMAIN, TYPE, PROTOCOL, TIMEOUT_ARGS
    @_ == 4
      or return $class->socketpair(@_);

    my $timeout_args = pop;

    my ($socket1, $socket2) = $class->socketpair(@_)
      or return;

    my %args = %$timeout_args;
    my $timeout_read = delete $args{TimeoutRead};
    my $timeout_write = delete $args{TimeoutWrite};

    my $strategy = delete $args{TimeoutStrategy} || $DEFAULT_STRATEGY;
    index( $strategy, '+' ) == 0
      or $strategy = 'IO::Socket::Timeout::Strategy::' . $strategy;
    load $strategy;

    # if no timeout feature is used, just call original class constructor
    $timeout_read && $timeout_read > 0 || $timeout_write && $timeout_write > 0
      or return $class->new(%args);

    # create our derivated class
    my $class_with_timeout = $class . '__WITH__'
      . join('_AND_',
             'READ' x !!$timeout_read,
             'WRITE' x !!$timeout_write)
      . '__'
      . $strategy;

    if ( ! $TIMEOUT_CLASS{$class_with_timeout} ) {
        no strict 'refs';
        push @{"${class_with_timeout}::ISA"}, $class;
        $strategy->apply_to_class($class_with_timeout, $timeout_read, $timeout_write);
        $TIMEOUT_CLASS{$class_with_timeout} = 1;
    }

    my $instance = $class_with_timeout->new(%args);
    $strategy->apply_to_instance($instance, $class_with_timeout, $timeout_read, $timeout_write);
    $instance;

}

1;
