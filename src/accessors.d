module accessors;

import std.traits;

struct Read
{
    string visibility = "public";
}

struct RefRead
{
    string visibility = "public";
}

struct ConstRead
{
    string visibility = "public";
}

struct Write
{
    string visibility = "public";
}

immutable string GenerateFieldAccessors = `
    mixin GenerateFieldAccessorMethods;
    mixin(GenerateFieldAccessorMethodsImpl);
    `;

mixin template GenerateFieldAccessorMethods()
{
    import std.meta : Alias, Filter;

    private enum bool isNotThis(string T) = T != "this";

    static enum GenerateFieldAccessorMethodsImpl()
    {
        import std.traits : hasUDA;

        string result = "";

        foreach (name; Filter!(isNotThis, __traits(derivedMembers, typeof(this))))
        {
            enum string fieldString = `Alias!(__traits(getMember, typeof(this), "` ~ name ~ `"))`;
            mixin("alias field = " ~ fieldString ~ ";");

            static if (__traits(compiles, hasUDA!(field, Read)))
            {
                static if (hasUDA!(field, Read))
                {
                    enum string readerDecl = GenerateReader!(name, field);
                    debug (accessors) pragma(msg, readerDecl);
                    result ~= readerDecl;
                }

                static if (hasUDA!(field, RefRead))
                {
                    enum string refReaderDecl = GenerateRefReader!(name, field);
                    debug (accessors) pragma(msg, refReaderDecl);
                    result ~= refReaderDecl;
                }

                static if (hasUDA!(field, ConstRead))
                {
                    enum string constReaderDecl = GenerateConstReader!(name, field);
                    debug (accessors) pragma(msg, constReaderDecl);
                    result ~= constReaderDecl;
                }

                static if (hasUDA!(field, Write))
                {
                    enum string writerDecl = GenerateWriter!(name, field, fieldString);
                    debug (accessors) pragma(msg, writerDecl);
                    result ~= writerDecl;
                }
            }
        }

        return result;
    }
}

template GenerateReader(string name, alias field)
{
    enum GenerateReader = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, Read);
        enum accessorName = accessor(name);
        enum needToDup = needToDup!field;

        static if (needToDup)
        {
            enum uint attributes = inferAttributes!(typeof(field[0]), "__postblit") &
                ~FunctionAttribute.nogc;
        }
        else
        {
            enum uint attributes = inferAttributes!(typeof(field), "__postblit");
        }

        string attributesString = generateAttributeString!attributes;

        static if (needToDup)
        {
            return format("%s final @property auto %s() %s"
                        ~ "{ return [] ~ this.%s; }",
                          visibility, accessorName, attributesString, name);
        }
        else
        {
            return format("%s final @property auto %s() inout %s{ return this.%s; }",
                visibility, accessorName, attributesString, name);
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int integerValue;
    string stringValue;
    int[] intArrayValue;

    static assert(GenerateReader!("foo", integerValue) ==
        "public final @property auto foo() " ~
        "inout @nogc nothrow pure @safe { return this.foo; }");
    static assert(GenerateReader!("foo", stringValue) ==
        "public final @property auto foo() " ~
        "inout @nogc nothrow pure @safe { return this.foo; }");
    static assert(GenerateReader!("foo", intArrayValue) ==
        "public final @property auto foo() nothrow pure @safe "
      ~ "{ return [] ~ this.foo; }");
}

template GenerateRefReader(string name, alias field)
{
    enum GenerateRefReader = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, RefRead);
        enum accessorName = accessor(name);

        return format("%s final @property ref auto %s() " ~
            "@nogc nothrow pure @safe { return this.%s; }",
            visibility, accessorName, name);
    }
}

///
@nogc nothrow pure @safe unittest
{
    int integerValue;
    string stringValue;
    int[] intArrayValue;

    static assert(GenerateRefReader!("foo", integerValue) ==
        "public final @property ref auto foo() " ~
        "@nogc nothrow pure @safe { return this.foo; }");
    static assert(GenerateRefReader!("foo", stringValue) ==
        "public final @property ref auto foo() " ~
        "@nogc nothrow pure @safe { return this.foo; }");
    static assert(GenerateRefReader!("foo", intArrayValue) ==
        "public final @property ref auto foo() " ~
        "@nogc nothrow pure @safe { return this.foo; }");
}

template GenerateConstReader(string name, alias field)
{
    enum GenerateConstReader = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, RefRead);
        enum accessorName = accessor(name);

        alias attributes = inferAttributes!(typeof(field), "__postblit");
        string attributesString = generateAttributeString!attributes;

        return format("%s final @property auto %s() const %s { return this.%s; }",
            visibility, accessorName, attributesString, name);
    }
}

template GenerateWriter(string name, alias field, string field_str)
{
    enum GenerateWriter = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, Write);
        enum accessorName = accessor(name);
        enum inputName = accessorName;
        enum needToDup = needToDup!field;

        static if (needToDup)
        {
            enum attributes = defaultFunctionAttributes &
                ~FunctionAttribute.nogc &
                inferAssignAttributes!(typeof(field[0])) &
                inferAttributes!(typeof(field[0]), "__postblit") &
                inferAttributes!(typeof(field[0]), "__dtor");
        }
        else
        {
            enum attributes = defaultFunctionAttributes &
                inferAssignAttributes!(typeof(field)) &
                inferAttributes!(typeof(field), "__postblit") &
                inferAttributes!(typeof(field), "__dtor");
        }

        enum attributesString = generateAttributeString!attributes;

        return format("%s final @property void %s(typeof(%s) %s) %s{ this.%s = %s%s; }",
            visibility, accessorName, field_str, inputName,
            attributesString, name, inputName, needToDup ? ".dup" : "");
    }
}

///
@nogc nothrow pure @safe unittest
{
    int integerValue;
    string stringValue;
    int[] intArrayValue;

    static assert(GenerateWriter!("foo", integerValue, "integerValue") ==
        "public final @property void foo(typeof(integerValue) foo) " ~
        "@nogc nothrow pure @safe { this.foo = foo; }");
    static assert(GenerateWriter!("foo", stringValue, "stringValue") ==
        "public final @property void foo(typeof(stringValue) foo) " ~
        "@nogc nothrow pure @safe { this.foo = foo; }");
    static assert(GenerateWriter!("foo", intArrayValue, "intArrayValue") ==
        "public final @property void foo(typeof(intArrayValue) foo) " ~
        "nothrow pure @safe { this.foo = foo.dup; }");
}

private enum uint defaultFunctionAttributes =
            FunctionAttribute.nogc |
            FunctionAttribute.safe |
            FunctionAttribute.nothrow_ |
            FunctionAttribute.pure_;

private template inferAttributes(T, string M)
{
    enum uint inferAttributes()
    {
        uint attributes = defaultFunctionAttributes;

        static if (is(T == struct))
        {
            static if (hasMember!(T, M))
            {
                attributes &= functionAttributes!(__traits(getMember, T, M));
            }
            else
            {
                foreach (field; Fields!T)
                {
                    attributes &= inferAttributes!(field, M);
                }
            }
        }
        return attributes;
    }
}

private template inferAssignAttributes(T)
{
    enum uint inferAssignAttributes()
    {
        uint attributes = defaultFunctionAttributes;

        static if (is(T == struct))
        {
            static if (hasMember!(T, "opAssign"))
            {
                foreach (o; __traits(getOverloads, T, "opAssign"))
                {
                    alias params = Parameters!o;
                    static if (params.length == 1 && is(params[0] == T))
                    {
                        attributes &= functionAttributes!o;
                    }
                }
            }
            else
            {
                foreach (field; Fields!T)
                {
                    attributes &= inferAssignAttributes!field;
                }
            }
        }
        return attributes;
    }
}

private template generateAttributeString(uint attributes)
{
    enum string generateAttributeString()
    {
        string attributesString;

        static if (attributes & FunctionAttribute.nogc)
        {
            attributesString ~= "@nogc ";
        }
        static if (attributes & FunctionAttribute.nothrow_)
        {
            attributesString ~= "nothrow ";
        }
        static if (attributes & FunctionAttribute.pure_)
        {
            attributesString ~= "pure ";
        }
        static if (attributes & FunctionAttribute.safe)
        {
            attributesString ~= "@safe ";
        }

        return attributesString;
    }
}

private template needToDup(alias field)
{
    enum needToDup = helper;

    static enum helper()
    {
        static if (isSomeString!(typeof(field)))
        {
            return false;
        }
        else
        {
            return isArray!(typeof(field));
        }
    }
}

@nogc nothrow pure @safe unittest
{
    int integerField;
    int[] integerArrayField;
    string stringField;

    static assert(!needToDup!integerField);
    static assert(needToDup!integerArrayField);
    static assert(!needToDup!stringField);
}

static string accessor(string name) @nogc nothrow pure @safe
{
    import std.string : chomp, chompPrefix;

    return name.chomp("_").chompPrefix("_");
}

///
@nogc nothrow pure @safe unittest
{
    assert(accessor("foo_") == "foo");
    assert(accessor("_foo") == "foo");
}

/**
 * Returns a string with the value of the field "visibility" if the field
 * is annotated with an UDA of type A. The default visibility is "public".
 */
template getVisibility(alias field, A)
{
    import std.string : format;

    enum getVisibility = helper;

    static enum helper()
    {
        alias attributes = getUDAs!(field, A);

        static if (attributes.length == 0)
        {
            return A.init.visibility;
        }
        else
        {
            static assert(attributes.length == 1,
                format("%s should not have more than one attribute @%s", field.stringof, A.stringof));

            static if (is(typeof(attributes[0])))
                return attributes[0].visibility;
            else
                return A.init.visibility;
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    @Read("public") int publicInt;
    @Read("package") int packageInt;
    @Read("protected") int protectedInt;
    @Read("private") int privateInt;
    @Read int defaultVisibleInt;
    @Read @Write("protected") int publicReadableProtectedWritableInt;

    static assert(getVisibility!(publicInt, Read) == "public");
    static assert(getVisibility!(packageInt, Read) == "package");
    static assert(getVisibility!(protectedInt, Read) == "protected");
    static assert(getVisibility!(privateInt, Read) == "private");
    static assert(getVisibility!(defaultVisibleInt, Read) == "public");
    static assert(getVisibility!(publicReadableProtectedWritableInt, Read) == "public");
    static assert(getVisibility!(publicReadableProtectedWritableInt, Write) == "protected");
}

/// Creates accessors for flags.
nothrow pure @safe unittest
{
    import std.typecons : Flag, No, Yes;

    class Test
    {
        @Read
        @Write
        public Flag!"someFlag" test_ = Yes.someFlag;

        mixin(GenerateFieldAccessors);
    }

    with (new Test)
    {
        assert(test == Yes.someFlag);

        test = No.someFlag;

        assert(test == No.someFlag);

        static assert(is(typeof(test) == Flag!"someFlag"));
    }
}

/// Creates accessors for Nullables.
nothrow pure @safe unittest
{
    import std.typecons : Nullable;

    class Test
    {
        @Read @Write
        public Nullable!string test_ = Nullable!string("X");

        mixin(GenerateFieldAccessors);
    }

    with (new Test)
    {
        assert(!test.isNull);
        assert(test.get == "X");

        static assert(is(typeof(test) == Nullable!string));
    }
}

/// Creates non-const reader.
nothrow pure @safe unittest
{
    class Test
    {
        @Read
        int i_;

        mixin(GenerateFieldAccessors);
    }

    auto mutableObject = new Test;
    const constObject = mutableObject;

    mutableObject.i_ = 42;

    assert(mutableObject.i == 42);

    static assert(is(typeof(mutableObject.i) == int));
    static assert(is(typeof(constObject.i) == const(int)));
}

/// Creates ref reader.
nothrow pure @safe unittest
{
    class Test
    {
        @RefRead
        int i_;

        mixin(GenerateFieldAccessors);
    }

    auto mutableTestObject = new Test;

    mutableTestObject.i = 42;

    assert(mutableTestObject.i == 42);
    static assert(is(typeof(mutableTestObject.i) == int));
}

/// Creates writer.
nothrow pure @safe unittest
{
    class Test
    {
        @Read @Write
        private int i_;

        mixin(GenerateFieldAccessors);
    }

    auto mutableTestObject = new Test;
    mutableTestObject.i = 42;

    assert(mutableTestObject.i == 42);
    static assert(!__traits(compiles, mutableTestObject.i += 1));
    static assert(is(typeof(mutableTestObject.i) == int));
}

/// Checks whether hasUDA can be used for each member.
nothrow pure @safe unittest
{
    class Test
    {
        alias Z = int;

        @Read @Write
        private int i_;

        mixin(GenerateFieldAccessors);
    }

    auto mutableTestObject = new Test;
    mutableTestObject.i = 42;

    assert(mutableTestObject.i == 42);
    static assert(!__traits(compiles, mutableTestObject.i += 1));
}

/// Returns non const for PODs and structs.
nothrow pure @safe unittest
{
    import std.algorithm : map, sort;
    import std.array : array;

    class C
    {
        @Read
        string s_;

        mixin(GenerateFieldAccessors);
    }

    C[] a = null;

    static assert(__traits(compiles, a.map!(c => c.s).array.sort()));
}

/// Regression.
nothrow pure @safe unittest
{
    class C
    {
        @Read @Write
        string s_;

        mixin(GenerateFieldAccessors);
    }

    with (new C)
    {
        s = "foo";
        assert(s == "foo");
        static assert(is(typeof(s) == string));
    }
}

/// Supports user-defined accessors.
nothrow pure @safe unittest
{
    class C
    {
        this()
        {
            str_ = "foo";
        }

        @RefRead
        private string str_;

        public @property const(string) str() const
        {
            return this.str_.dup;
        }

        mixin(GenerateFieldAccessors);
    }

    with (new C)
    {
        str = "bar";
    }
}

/// Creates accessor for locally defined types.
@system unittest
{
    class X
    {
    }

    class Test
    {
        @Read
        public X x_;

        mixin(GenerateFieldAccessors);
    }

    with (new Test)
    {
        x_ = new X;

        assert(x == x_);
        static assert(is(typeof(x) == X));
    }
}

/// Creates const reader for simple structs.
nothrow pure @safe unittest
{
    class Test
    {
        struct S
        {
            int i;
        }

        @Read
        S s_;

        mixin(GenerateFieldAccessors);
    }

    auto mutableObject = new Test;
    const constObject = mutableObject;

    mutableObject.s_.i = 42;

    assert(constObject.s.i == 42);

    static assert(is(typeof(mutableObject.s) == Test.S));
    static assert(is(typeof(constObject.s) == const(Test.S)));
}

/// Reader for structs return copies.
nothrow pure @safe unittest
{
    class Test
    {
        struct S
        {
            int i;
        }

        @Read
        S s_;

        mixin(GenerateFieldAccessors);
    }

    auto mutableObject = new Test;

    mutableObject.s.i = 42;

    assert(mutableObject.s.i == int.init);
}

/// Creates reader for const arrays.
nothrow pure @safe unittest
{
    class X
    {
    }

    class C
    {
        @Read
        private const(X)[] foo_;

        mixin(GenerateFieldAccessors);
    }

    auto x = new X;

    with (new C)
    {
        foo_ = [x];

        auto y = foo;

        static assert(is(typeof(y) == const(X)[]));
        static assert(is(typeof(foo) == const(X)[]));
    }
}

/// Property has correct type.
nothrow pure @safe unittest
{
    class C
    {
        @Read
        private int foo_;

        mixin(GenerateFieldAccessors);
    }

    with (new C)
    {
        static assert(is(typeof(foo) == int));
    }
}

/// Inheritance (https://github.com/funkwerk/accessors/issues/5).
@nogc nothrow pure @safe unittest
{
    class A
    {
        @Read
        string foo_;

        mixin(GenerateFieldAccessors);
    }

    class B : A
    {
        @Read
        string bar_;

        mixin(GenerateFieldAccessors);
    }
}

/// Transfers struct attributes.
@nogc nothrow pure @safe unittest
{
    struct S
    {
        this(this)
        {
        }

        void opAssign(S s)
        {
        }
    }

    class A
    {
        @Read
        S[] foo_;

        @ConstRead
        S bar_;

        @Write
        S baz_;

        mixin(GenerateFieldAccessors);
    }
}

/// @Read property returns array with mutable elements.
nothrow pure @safe unittest
{
    struct Field
    {
    }

    struct S
    {
        @Read
        Field[] foo_;

        mixin(GenerateFieldAccessors);
    }

    with (S())
    {
        Field[] arr = foo;
    }
}
