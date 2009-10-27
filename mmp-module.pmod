//! @returns
//! @int
//! 	@value 1
//! 		@expr{o@} is a @[Uniform].
//! 	@value 0
//! 		@expr{o@} is not a @[Uniform].
//! @endint
int(0..1) is_uniform(mixed o) {
    if (objectp(o) && Program.inherits(object_program(o), Uniform)) {
	return 1;
    } else {
	return 0;
    }
}

//! @returns
//! @int
//! 	@value 1
//! 		@expr{o@} is a MMP.Uniform designated by @expr{designator@}
//! 	@value 0
//! 		@expr{o@} is not a Person.
//! @endint
//!
//! @seealso
//!	@[is_person()], @[is_place()], @[is_uniform()]
int(0..1) is_thing(mixed o, int designator) {
    return is_uniform(o) && stringp(o->resource) && sizeof(o->resource) && o->resource[0] == designator;
}

//! @returns
//! @int
//! 	@value 1
//! 		@expr{o@} is a Person (designated by an '~' in MMP/PSYC).
//! 	@value 0
//! 		@expr{o@} is not a Person.
//! @endint
//!
//! @seealso
//!	@[is_thing()], @[is_place()], @[is_uniform()]
int(0..1) is_person(mixed o) {
    return is_thing(o, '~');
}

//! @returns
//! @int
//! 	@value 1
//! 		@expr{o@} is a Place (designated by an '@@' in MMP/PSYC).
//! 	@value 0
//! 		@expr{o@} is not a Place.
//! @endint
//! @seealso
//!	@[is_thing()], @[is_person()], @[is_uniform()]
int(0..1) is_place(mixed o) {
    return is_thing(o, '@');
}

