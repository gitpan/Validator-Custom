package Validator::Custom::Rules;
use Object::Simple -base;

use Validator::Custom::Rule;

has rules => sub { {} };

sub add {
  my ($self, $name, $rule) = @_;
  
  my $rules = $self->rules;
  
  if (ref $rule eq 'Validator::Custom::Rule') {
    $rules->{$name} = $rule;
  }
  else {
    my $rule_obj = Validator::Custom::Rule->new;
    $rule_obj->parse($rule);
    $rules->{$name} = $rule_obj;
  }
  
  return $self;
}

sub filter {
  my ($self, $name, $types) = @_;
  
  $self->{_filter} ||= {};
  $self->{_filter}{$name} = $types;
  
  return $self;
}

sub get {
  my ($self, $name, $type) = @_;
  
  if (defined $type) {
    my $filter = $self->{_filter} || {};
    my $types = $self->{_filter}->{$name}{$type};
    
    my $rule_all = $self->rules->{$name};
    my $rule = [];
    for my $key (@$types) {
      for my $item (@{$rule_all->rule}) {
        my $result_key;
        if (ref $item->{key} eq 'HASH') {
          $result_key = (keys %{$item->{key}})[0];
        }
        else {
          $result_key = $item->{key};
        }
        if ($result_key eq $key) {
          push @$rule, $item;
        }
      }
    }
    my $rule_obj = Validator::Custom::Rule->new;
    $rule_obj->rule($rule);
  }
  else {
    return $self->rules->{$name};
  }
}

1;

=head1 NAME

Validator::Custom::Rules - Rules (EXPERIMENTAL)

=head1 SYNOPSYS
  
  # Rules object
  my $rules = Validator::Custom::Rules->new;
  
  # Add rule
  $rules->add(user => [
    id => [
      'not_blank',
      'ascii'
    ],
    name => [
      'not_blank',
      {length => [1, 30]}
    ],
    age => [
      'uint'
    ]
  ]);
  
  # Get rule
  my $rule_user = $rules->get('user');
  
  # Filter
  $rules->filter('user' => {
    insert => ['name', 'age'],
    update => ['id', 'name', 'age'],
    delete => ['id']
  });
  
  # Get rule with filtering
  my $rule_user_insert = $rules->get('user', 'insert');
  my $rule_user_update = $rules->get('user', 'update');
  my $rule_user_delete = $rules->get('user', 'delete');

=head1 DESCRIPTION

Validation::Custom::Rules is class to store and retreive rule and provide filter.

=head1 ATTRIBUTES

=head2 rules

  my $content = $rules->rules;
  $rules = $rules->rules($content);

Content of rules object.

=head1 METHODS

=head1 add

  $rules = $rules->add($name => $rule);

Add rule.

You can add rule or rule object.
  
  # Rule
  my $rule = [
    id => [
      'not_blank',
      'ascii'
    ],
    name => [
      'not_blank',
      {length => [1, 30]}
    ],
    age => [
      'uint'
    ]
  ]
  $rules->add(user => $rule);
  
  # Rule object
  my $rule_obj = Validator::Custom::Rule->new;
  $rule_obj->parse($rule);
  $rules->add(user => $rule_obj);

=head1 filter

  $rules = $rules->filter($name => $filtering);

Resister filtering.

  # Filter
  $rules->filter('user' => {
    insert => ['name', 'age'],
    update => ['id', 'name', 'age'],
    delete => ['id']
  });

C<get> method use these filtering.

  my $rule_user_insert = $rules->get('user', 'insert');

=head1 get

  $rules = $rules->get($name);
  $rules = $rules->get($name, $filter_name);

Get rule.

  # Get rule
  my $rule_user = $rules->get('user');

You can specify filtering.

  # Get rule with filtering
  my $rule_user_insert = $rules->get('user', 'insert');
  my $rule_user_update = $rules->get('user', 'update');
  my $rule_user_delete = $rules->get('user', 'delete');
