module accessors;

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
            alias field = Alias!(__traits(getMember, typeof(this), name));

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
                    enum string writerDecl = GenerateWriter!(name, field);
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
        import std.traits : isArray, isSomeString;

        enum visibility = getVisibility!(field, Read);
        enum accessorName = accessor(name);

        static if (isArray!(typeof(field)) && !isSomeString!(typeof(field)))
        {
            return format("%s final @property auto %s() {"
                        ~ "return [] ~ this.%s;"
                        ~ "}",
                          visibility, accessorName, name);
        }
        else
        {
           return format("%s final @property auto %s() inout { return this.%s; }",
                         visibility, accessorName, name);
        }
    }
}

///
unittest
{
    int integerValue;
    string stringValue;
    int[] intArrayValue;

    static assert(GenerateReader!("foo", integerValue) ==
        "public final @property auto foo() inout { return this.foo; }");
    static assert(GenerateReader!("foo", stringValue) ==
        "public final @property auto foo() inout { return this.foo; }");
    static assert(GenerateReader!("foo", intArrayValue) ==
        "public final @property auto foo() {"
      ~ "return [] ~ this.foo;"
      ~ "}");
}

template GenerateRefReader(string name, alias field)
{
    enum GenerateRefReader = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, RefRead);
        enum accessorName = accessor(name);

        return format("%s final @property ref auto %s() { return this.%s; }",
                      visibility, accessorName, name);
    }
}

///
unittest
{
    int integerValue;
    string stringValue;
    int[] intArrayValue;

    static assert(GenerateRefReader!("foo", integerValue) ==
        "public final @property ref auto foo() { return this.foo; }");
    static assert(GenerateRefReader!("foo", stringValue) ==
        "public final @property ref auto foo() { return this.foo; }");
    static assert(GenerateRefReader!("foo", intArrayValue) ==
        "public final @property ref auto foo() { return this.foo; }");
}

template GenerateConstReader(string name, alias field)
{
    enum GenerateConstReader = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, RefRead);
        enum accessorName = accessor(name);

        return format("%s final @property auto %s() const { return this.%s; }",
                      visibility, accessorName, name);
    }
}

template GenerateWriter(string name, alias field)
{
    enum GenerateWriter = helper;

    static enum helper()
    {
        import std.string : format;

        enum visibility = getVisibility!(field, Write);
        enum accessorName = accessor(name);
        enum inputType = typeName!(typeof(field));
        enum inputName = accessorName;
        enum needToDup = needToDup!field;

        return format("%s final @property void %s(%s %s) { this.%s = %s%s; }",
            visibility, accessorName, inputType, inputName, name, inputName, needToDup ? ".dup" : "");
    }
}

///
unittest
{
    int integerValue;
    string stringValue;
    int[] intArrayValue;

    static assert(GenerateWriter!("foo", integerValue) ==
        "public final @property void foo(int foo) { this.foo = foo; }");
    static assert(GenerateWriter!("foo", stringValue) ==
        "public final @property void foo(string foo) { this.foo = foo; }");
    static assert(GenerateWriter!("foo", intArrayValue) ==
        "public final @property void foo(int[] foo) { this.foo = foo.dup; }");
}

/**
 * This template returns the name of a type used in attribute readers and writers.
 * While it should be safe to use fullyQualifiedName everywhere, this does not work for
 * types defined in methods. Unfortunately it is required to use it for Flags.
 * Flags seem to be somehow special here.
 */
private template typeName(T)
{
    enum typeName = helper;

    static enum helper()
    {
        import std.array : replaceLast;
        import std.traits : fullyQualifiedName;

        static if (T.stringof == "Flag" || T.stringof == "const(Flag)")
        {
            return fullyQualifiedName!T["std.typecons.".length .. $];
        }
        else static if (__traits(compiles, __traits(identifier, T)) && __traits(identifier, T) == "BitFlags")
        {
            return T.stringof.replaceLast("(Flag)", `(Flag!"unsafe")`);
        }
        else static if (__traits(compiles, localTypeName!T))
        {
            return localTypeName!T;
        }
        else
        {
            return T.stringof;
        }
    }
}

unittest
{
    import std.typecons : Flag, BitFlags, Yes, No;

    enum E
    {
        A = 0,
        B = 2,
    }

    static assert(typeName!int == "int");
    static assert(typeName!string == "string");
    static assert(typeName!(BitFlags!E) == `BitFlags!(E, cast(Flag!"unsafe")false)`);
    static assert(typeName!(BitFlags!(E, Yes.unsafe)) == `BitFlags!(E, cast(Flag!"unsafe")true)`);
    static assert(typeName!(Flag!"foo") == `Flag!("foo")`);
}

private template localTypeName(T)
{
    enum localTypeName = helper;

    static enum helper()
    {
        import std.algorithm : find, startsWith;
        import std.array : replaceLast;
        import std.traits : fullyQualifiedName, moduleName, Unqual;

        alias fullyQualifiedTypeName = fullyQualifiedName!(Unqual!T);
        string typeName = fullyQualifiedTypeName[moduleName!T.length + 1 .. $];

        // classes defined in unittest blocks have a prefix like __unittestL526_18
        version (unittest)
        {
            if (typeName.startsWith("__unittestL"))
            {
                typeName = typeName.find(".")[1 .. $];
            }
        }
        return fullyQualifiedName!T.replaceLast(fullyQualifiedTypeName, typeName);
    }
}

unittest
{
    class C
    {
    }

    static assert(localTypeName!C == "C");
}

private template needToDup(alias field)
{
    enum needToDup = helper;

    static enum helper()
    {
        import std.traits : isArray, isSomeString;

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

unittest
{
    int integerField;
    int[] integerArrayField;
    string stringField;

    static assert(!needToDup!integerField);
    static assert(needToDup!integerArrayField);
    static assert(!needToDup!stringField);
}

static string accessor(string name)
{
    import std.string : chomp, chompPrefix;

    return name.chomp("_").chompPrefix("_");
}

///
unittest
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
    import std.traits : getUDAs;
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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
unittest
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

/// Inheritance (https://github.com/funkwerk/accessors/issues/5)
unittest
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

/// @Read property returns array with mutable elements.
unittest
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
