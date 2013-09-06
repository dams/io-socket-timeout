package IO::Socket::Timeout::Strategy;

use strict;
use warnings;

use Scalar::Util qw(reftype);
use Class::Method::Modifiers qw(install_modifier);

# ABSTRACT: base class for timeout strategies

sub apply_to_class {
    my ($class, $into, $timeout_read, $timeout_write) = @_;
    install_modifier($into, 'around', new => \&new_wrapper);

}

sub new_wrapper {
    my $orig = shift;

    my $first_arg = $_[0];
    my $instance = $orig->(@_);

    # if we are created from an other socket, like the 'accept' function
    my $reftype = reftype($first_arg);
    if (defined $reftype && $reftype eq 'GLOB') {
        ${*$instance}{$_} = ${*$first_arg}{$_} foreach grep { /^__/ } keys %{*$first_arg};
    }

    return $instance;
}
1;
