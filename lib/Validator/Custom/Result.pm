package Validator::Custom::Result;
use Object::Simple;

# Invalid keys
sub invalid_keys : Attr   { type => 'array', default => sub{ [] }, deref => 1 }

# Validation errors
sub errors       : Attr   { type => 'array', default => sub{ [] }, deref => 1 }

# Resutls after conversion
sub products     : Attr   { type => 'hash', default => sub{ {} }, deref => 1 }

# Check valid or not
sub is_valid {
    my $self = shift;
    return @{$self->invalid_keys} ? 0 : 1;
}

# Build class
Object::Simple->build_class;


=head1 Validator::Custom::Result

=head1 NAME

Validator::Custom::Result - Validator::Custom result object

=head1 SYNOPSYS
    
    # Error message
    @errors = $result->errors;
    
    # Invalid keys
    @invalid_keys = $result->invalid_keys;
    
    # Producted values
    $products = $result->products;
    $product  = $products->{key1};
    
    # Is it valid?
    $is_valid = $result->is_valid;

=head1 Accessors

=head2 errors

You can get validation errors

Set and get errors

    $result = $result->errors($error);
    
    $errors = $result->errors
    @errors = $result->errors

=head2 invalid_keys

Set and get invalid keys

    $result       = $result->invalid_keys($invalid_keys);

    @invalid_keys = $result->invalid_keys
    $invalid_keys = $result->invalid_keys

=head2 products

Set and get producted values

    $result   = $result->products($products);
    $products = $result->products

    $product = $products->{key}

=head1 Methods

=head2 is_valid

Check if invalid_keys exsits or not

    $is_valid = $result->is_valid;

=head1 See also

L<Validator::Custom>

=cut
