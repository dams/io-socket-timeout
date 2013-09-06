package IO::Socket::Timeout::Strategy;

use strict;
use warnings;

use Class::Method::Modifiers qw(install_modifier);

# ABSTRACT: base class for timeout strategies

use Data::Dumper;
sub apply_to_class {
    my ($class, $into, $timeout_read, $timeout_write) = @_;
    install_modifier($into, 'around', new => \&new_wrapper);

}

sub new_wrapper {
    my $orig = shift;

    my $first_arg = $_[0];
    print STDERR " *********************************** FIRST ARG $first_arg\n";
    my $instance = $orig->(@_);

    # if we are created from an other socket, like in accept
    if (ref $first_arg ) {
        ${*$instance}{$_} = ${*$first_arg}{$_} foreach grep { /^__/ } keys %{*$first_arg};
    }

#    ${*$instance}{__is_valid__} or $! = ECONNRESET, return;

#    ${*$self}{__select__}->can_read(${*$self}{__timeout_read__})
#      and return 

#    clean($self);
#    $! = ETIMEDOUT;
    return $instance;
}
1;
