package IO::Socket::Timeout;

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
  my $socket = IO::Socket::INET->new::with::timeout( Timeout => 5,
                                                     TimeoutRead => 5,
                                                     # other standard arguments );

  my $socket = IO::Socket::UNIX->new::with::timeout( Timeout => 5,
                                                     TimeoutRead => 5,
                                                     TimeoutWrite => 5,
                                                     # other standard arguments );

  my $socket = IO::Socket->new::with::timeout( Timeout => 5,
                                               TimeoutReadWrite => 5,
                                               TimeoutStrategy => 'Alarm',
                                               # other standard arguments );

  my $socket = IO::Socket->new::with::timeout( Timeout => 5,
                                               TimeoutReadWrite => 5,
                                               TimeoutStrategy => '+My::Own::Strategy',
                                               # other standard arguments );

  

=head1 CONSTRUCTOR

=head2 new_with_timeout

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

If set to a value, the socket will timeout on reads.

=item TimeoutWrite

If set to a value, the socket will timeout on writes.

=item TimeoutStrategy

Used to specify the timeout implementation used. The value should be a module
name. If it B<doesn't> start with C<+>, the value will be prepended with
C<IO::Socket::Timeout::Strategy::>. If it B<does> start with C<+>, the value is
expected to be the fullname of a module. The default value is C<'Select'>.

=back

=cut

use Module::Load qw(load);

use Class::Method::Modifiers qw(install_modifier);

sub new::with::timeout {
    my ($class, %args) = @_;
    $class->isa('IO::Socket') && $class->can('sysread') && $class->can('syswrite')
      or croak 'new::with::timeout can be used only on classes that isa IO::Socket and can sysread() and syswrite()';

    my $timeout_read = delete $args{TimeoutRead};
    my $timeout_write = delete $args{TimeoutWrite};

    $timeout_read || $timeout_write
      or return $class->new(%args);

    my $class_with_timeout = $class . '::With::Timeout'

    my $strategy = delete $args{TimeoutStrategy} || 'Select';
    index( $strategy, '+' ) == 0
      or $strategy = 'IO::Socket::Timeout::Strategy::' . $strategy;
    load $strategy;

    push @{"${class_with_timeout}::ISA"}, $class;
    $strategy->apply_to($class_with_timeout, $timeout_read, $timeout_write);

    $class_with_timeout->new(%args);

}
