import accessors;

void main()
{
}

// Issue #11: https://github.com/funkwerk/accessors/issues/11
pure nothrow @safe @nogc unittest
{
    import PersonId : AnotherPersonId = PersonId;

    class PersonId
    {
    }

    class Foo
    {
        @ConstRead
        private AnotherPersonId anotherPersonId_;

        @Read
        private AnotherPersonId[] personIdArray_;

        mixin(GenerateFieldAccessors);
    }
}
