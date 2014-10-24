package Validator::Custom;
use Object::Simple;

use strict;
use warnings;
use Carp 'croak';

our $VERSION = '0.0606';

### Class methods

# Get constraint functions
sub constraints : ClassObjectAttr {
    type => 'hash',
    deref => 1,
    initialize => {
        clone   => 'hash',
        default => sub { {} }
    }
}

# Add constraint function
sub add_constraint {
    my $invocant = shift;
    
    my %old_constraints = $invocant->constraints;
    my %new_constraints = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    $invocant->constraints(%old_constraints, %new_constraints);
}

### Accessors

# Validation rule
sub validation_rule : Attr {}

# Error is stock?
sub error_stock  : Attr { default => 1 }

### Methods

# Validate
sub validate {
    my ($self, $data, $validation_rule) = @_;
    my $class = ref $self;
    
    # Validation rule
    $validation_rule ||= $self->validation_rule;
    
    # Data must be hash ref
    croak "Data which passed to validate method must be hash ref"
      unless ref $data eq 'HASH';
    
    # Validation rule must be array ref
    croak "Validation rule must be array ref\n" .
          "(see syntax of validation rule 1)\n" .
          $self->_validation_rule_usage($validation_rule)
      unless ref $validation_rule eq 'ARRAY';
    
    # Result object
    my $result = Validator::Custom::Result->new;
    
    # Error is stock?
    my $error_stock = $self->error_stock;
    
    # Process each key
    VALIDATOR_LOOP:
    for (my $i = 0; $i < @{$validation_rule}; $i += 2) {
        my ($key, $constraints) = @{$validation_rule}[$i, ($i + 1)];
        
        croak "Constraints of validation rule must be array ref\n" .
              "(see syntax of validation rule 2)\n" .
              $self->_validation_rule_usage($validation_rule)
          unless ref $constraints eq 'ARRAY';
        
        # Rearrange key
        my $product_key = $key;
        
        if (ref $key eq 'HASH') {
            my $first_key = (keys %$key)[0];
            ($product_key, $key) = ($first_key, $key->{$first_key});
        }
        
        my $value;
        my $products;
        foreach my $constraint (@$constraints) {
            
            # Rearrange validator information
            my ($constraint, $error_message)
              = ref $constraint eq 'ARRAY' ? @$constraint : ($constraint);
            
            my $data_type = {};
            my $arg;
            
            if(ref $constraint eq 'HASH') {
                my $first_key = (keys %$constraint)[0];
                ($constraint, $arg) = ($first_key, $constraint->{$first_key});
            }
            
            my $constraint_function;
            # Expression is code reference
            if( ref $constraint eq 'CODE') {
                $constraint_function = $constraint;
            }
            
            # Expression is string
            else {
                if($constraint =~ /^\@(.+)$/) {
                    $data_type->{array} = 1;
                    $constraint = $1;
                }
                
                croak "Constraint type '$constraint' must be [A-Za-z0-9_]"
                  if $constraint =~ /\W/;
                
                # Get validator function
                $constraint_function = $self->constraints->{$constraint};
                
                croak "'$constraint' is not resisted"
                  unless ref $constraint_function eq 'CODE'
            }
            
            # Validate
            my $is_valid;
            if($data_type->{array}) {
                
                $value = ref $data->{$key} eq 'ARRAY' ? $data->{$key} : [$data->{$key}]
                  unless defined $value;
                
                my $first_validation = 1;
                foreach my $data (@$value) {
                    my $product;
                    ($is_valid, $product) = eval{$constraint_function->($data, $arg, $self)};
                    
                    croak $@ if $@;
                    
                    last unless $is_valid;
                    
                    if (defined $product) {
                        if ($first_validation) {
                            $products = [];
                            $first_validation = 0;
                        }
                        push @{$products}, $product;
                    }
                }
                $value = $products if defined $products;
            }
            else {
                $value = ref $key eq 'ARRAY' ? [map { $data->{$_} } @$key] : $data->{$key}
                  unless defined $value;
                
                ($is_valid, $products) = eval{$constraint_function->($value, $arg, $self)};
                
                croak $@ if $@;
                
                $value = $products if $is_valid && defined $products;
            }
            
            # Add error if it is invalid
            unless($is_valid){
                $products = undef;
                
                push @{$result->errors}, $error_message if defined $error_message;
                push @{$result->invalid_keys}, $product_key;
                
                last VALIDATOR_LOOP unless $error_stock;
                next VALIDATOR_LOOP;
            }
        }
        $result->products->{$product_key} = $products if defined $products;
    }
    return $result;
}

my $SYNTAX_OF_VALIDATION_RULE = <<'EOS';

### Syntax of validation rule         
my $validation_rule = [               # 1.Validation rule must be array ref
    key1 => [                         # 2.Constraints must be array ref
        'constraint1_1',              # 3.Constraint can be string
        ['constraint1_2', 'error1_2'],#     or arrya ref (error message)
        {'constraint1_3' => 'string'} #     or hash ref (arguments)
          
    ],
    key2 => [
        {'constraint2_1'              # 4.Argument can be string
          => 'string'},               #
        {'constraint2_2'              #     or array ref
          => ['arg1', 'arg2']},       #
        {'constraint1_3'              #     or hash ref
          => {k1 => 'v1', k2 => 'v2}} #
    ],
    key3 => [                           
        [{constraint3_1' => 'string'},# 5.Combination argument
         'error3_1' ]                 #     and error message
    ],
    { key4 => ['key4_1', 'key4_2'] }  # 6.Multi key validation
        => [
            'constraint4_1'
           ]
    key5 => [
        '@constraint5_1'              # 7.Array each value validation
    ]
];

EOS

# Validation rule usage
sub _validation_rule_usage {
    my ($self, $validation_rule) = @_;
    
    my $message = $SYNTAX_OF_VALIDATION_RULE;
    
    require Data::Dumper;
    $message .= "### Your validation rule:\n";
    $message .= Data::Dumper->Dump([$validation_rule], ['$validation_rule']);
    $message .= "\n";
    return $message;
}

# Build class
Object::Simple->build_class;

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



package Validator::Custom;
1;

=head1 NAME

Validator::Custom - Custom validator

=head1 Version

Version 0.0606

=head1 Synopsis
    
    ### How to use Validator::Custom
    
    # Data
    my $data = { k1 => 1, k2 => 2 };
    
    # Validate
    my $vc = Validator::Custom->new
    
    $vc->add_constraints(
        int => sub { my $value = shift; return $value =~ /^\d+$/; }
    );
    
    $vc->validation_rule([
        k1 => [
            'int'
        ],
        k2 => [
            'int'
        ]
    ]);
    
    my $result = $vc->validate($data,$validation_rule);
    
    # Get errors
    my @errors = $result->errors;
    
    # Handle errors
    foreach my $error (@$errors) {
        # ...
    }
    
    # Get invalid keys
    my @invalid_keys = $result->invalid_keys;
    
    # Get converted value
    my $products = $result->products;
    $product = $products->{key1};
    
    # Check valid or not
    if($result->is_valid) {
        # ...
    }
    
    ### How to costomize Validator::Custom
    package Validator::Custom::Yours;
    use base 'Validator::Custom';
    
    # regist custom type
    __PACKAGE__->add_constraint(
        Int => sub {$_[0] =~ /^\d+$/},
        Num => sub {
            require Scalar::Util;
            Scalar::Util::looks_like_number($_[0]);
        },
        Str => sub {!ref $_[0]}
    );
    
    ### How to use customized validator class
    use Validator::Custom::Yours;
    my $data = { age => 'aaa', weight => 'bbb', favarite => [qw/sport food/};
    
    # Validation rule normal syntax
    my $validation_rule = [
        title => [
            ['Int', "Must be integer"],
        ],
        content => [
            ['Num', "Must be number"],
        ],
        favorite => [
            ['@Str', "Must be string"]
        ]
    ];
    
    # Validation rule light syntax
    my $validation_rule = [
        title => [
            'Int',
        ],
        content => [
            'Num',
        ],
        favorite => [
            '@Str'
        ]
    ];
    
    # Corelative check
    my $validation_rule => [
        [qw/password1 password2/] => [
            ['Same', 'passwor is not same']
        ]
    ]
    
    # Specify keys
    my $validation_rule => [
        {password_check => [qw/password1 password2/]} => [
            ['Same', 'passwor is not same']
        ]
    ]
    
    
=head1 Class-Object accessors

Class-Object accessor is accessor for both class attribute and object attribute.

=head2 constraints

get constraints
    
    # Set and get constraint functions
    $class       = Validator::Custom->constraints($constraints);
    $constraints = Validator::Custom->constraints;
    
    $self        = $vc->constraints($constraints);
    $constraints = $vc->constraints;

$constraints muset be hash or hash reference

    # Sample (hash)
    $vc->constraints(
        int    => sub { ... },
        string => sub { ... }
    );
    
    # Sample (hash reference)
    $vc->constraints({
        int    => sub { ... },
        string => sub { ... }
    });

See also add_constraint for adding constraint function

=head1 Object accessors

=head2 error_stock

If you stock error, set 1, or set 0.

Default is 1. 

=head2 validation_rule

You can set validation_rule

    $vc->validation_rule($validation_rule);

Validation rule is the following

    ### Syntax of validation rule         
    my $validation_rule = [               # 1.Validation rule must be array ref
        key1 => [                         # 2.Constraints must be array ref
            'constraint1_1',              # 3.Constraint can be string
            ['constraint1_2', 'error1_2'],#     or arrya ref (error message)
            {'constraint1_3' => 'string'} #     or hash ref (arguments)
              
        ],
        key2 => [
            {'constraint2_1'              # 4.Argument can be string
              => 'string'},               #
            {'constraint2_2'              #     or array ref
              => ['arg1', 'arg2']},       #
            {'constraint1_3'              #     or hash ref
              => {k1 => 'v1', k2 => 'v2}} #
        ],
        key3 => [                           
            [{constraint3_1' => 'string'},# 5.Combination argument
             'error3_1' ]                 #     and error message
        ],
        { key4 => ['key4_1', 'key4_2'] }  # 6.Multi key validation
            => [
                'constraint4_1'
               ]
        key5 => [
            '@constraint5_1'              # 7. array ref each value validation
        ]
    ];

=head1 Class-Object mehtods

=head2 add_constraint

    # add constraint
    $class = Validator::Custom->constraint($constraint);
    $self  = $vc->constraint($constraint);

You can use this method in custom class.
New validator functions is added.
    
    package Validator::Custom::Yours;
    use base 'Validator::Custom';
    
    __PACKAGE__->add_constraint(
        Int => sub {$_[0] =~ /^\d+$/}
    );

You can merge multi custom class

    package Validator::Custom::Yours3;
    use base 'Validator::Custom';
    
    use Validator::Custum::Yours1;
    use Validatro::Cumtum::Yours2;
    
    __PACAKGE__->add_constraint(
        Validator::Custom::Yours1->constraints,
        Validator::Custom::Yours2->constraints
    );

=head1 Object methods

=head2 new
    # Create objct
    my $vc = Validator::Costom->new;


=head2 validate

validate

    # Do validation
    my $result = $vc->validate($data,$validation_rule);
    my $result = $vc->validate($data)

If you omit $validation_rule, $vc->validation_rule is used.
 
Validation rule is like the following.

    my $validation_rule = [
        # Custom Type
        key1 => [
            [ 'CustomType' ,         "Error message2-1"],
        ],
        
        # Array of Custom Type
        key2 => [
            [ '@CustomType',         "Error message3-1"]
        ]
    ];

$result is Validator::Custom::Result object.
This have 'errors', 'invalid_keys', and 'products' methods.

Error messages is saved to 'errors' if some error occured.
Invalid keys is saved to 'invalid_keys' if some error occured.
Conversion products is saved to 'products' if convertion is excuted.


=head1 Validator::Custom::Result object

=head2 errors

You can get validation errors
    
    $errors = $result->errors
    @errors = $result->errors

=head2 invalid_keys

You can get invalid keys

    @invalid_keys = $result->invalid_keys
    $invalid_keys = $result->invalid_keys

=head2 products

You can get converted data.

    $products = $result->products

This is hash ref. You can get each product by specify key.

    $product = $products->{key}

=head2 is_valid

You can check data is valid or not

    my $is_valid = $result->is_valid;

=cut

=head1 Author

Yuki Kimoto, C<< <kimoto.yuki at gmail.com> >>

Github L<http://github.com/yuki-kimoto>

I develope this module at L<http://github.com/yuki-kimoto/Validator-Custom>

Please send message if you find bug or want to suggest something.

I also support at IRC irc.perl.org#validator-custom

=head1 Copyright & licence

Copyright 2009 Yuki Kimoto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Validator::Custom
