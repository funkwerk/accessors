# accessors

[![Build Status](https://travis-ci.org/funkwerk/accessors.svg?branch=master)](https://travis-ci.org/funkwerk/accessors)
[![License](https://img.shields.io/badge/license-BSL_1.0-blue.svg)](https://raw.githubusercontent.com/funkwerk/accessors/master/LICENSE)
[![Dub Version](https://img.shields.io/dub/v/accessors.svg)](https://code.dlang.org/packages/accessors)
[![codecov](https://codecov.io/gh/funkwerk/accessors/branch/master/graph/badge.svg)](https://codecov.io/gh/funkwerk/accessors)

`accessors` module allows to generate getters and setters automatically.

**Deprecation warning:** `accessors` has been succeeded by [boilerplate](https://github.com/funkwerk/boilerplate).

## Usage

```d
import accessors;

class WithAccessors
{
    @Read @Write
    private int num_;

    mixin(GenerateFieldAccessors);
}
```

`@Read` and `@Write` generate the following two methods:

```d
public final @property auto num() inout @nogc nothrow pure @safe
{
    return this.num_;
}

public final @property void num(int num) @nogc nothrow pure @safe
{
    this.num_ = num;
}
```

The accessors names are derived from the appropriate member variables by
removing an underscore from the beginning or the end of the variable name.

### Available user defined attributes

* `@Read`
* `@ConstRead`
* `@Write`

As you can see there are multiple attributes that can be used to generate
getters and only one for the setters. The getters differ by the return
type. `@Read` returns an `inout` value, `@ConstRead` - a `const` value.

### Accessor visibility

Visibility of the generated accessors is by default `public`, but it can be
changed. In order to achieve this, you have to pass `public`, `protected`,
`private` or `package` as argument to the attribute:

```d
import accessors;

class WithAccessors
{
    @Read("public") @Write("protected")
    private int num_;

    mixin(GenerateFieldAccessors);
}
```

## Example

```d
import accessors;
import std.stdio;

class Person
{
    @Read @Write
    private uint age_;

    @ConstRead
    private string name_;

    this(in string name, in uint age = 0)
    {
        this.name_ = name;
        this.age_ = age;
    }

    mixin(GenerateFieldAccessors);
}

void main()
{
    auto person = new Person("Saul Kripke");

    person.age = 57;

    writeln(person.name, ": ", person.age);
}
```

## Bugs

If you experience compile-time problems, open an
[issue](https://github.com/funkwerk/accessors/issues) with the
information about the type of the member variable fails.
