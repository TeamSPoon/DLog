options([abox_target(allinonefile), tbox_target(allinonefile)]).

query(instances(aconcept('Happy')), [i1, i2, i3, i4, i5, i6]).
%query(roleFillers(i3, arole(hasDescendant)), [i4, i5, i6, i7, i8, i9, i10, i11, i12]).

concept('Happy').
concept('Clever').
role(hasChild).
role(hasDescendant).
role(hasRelative).

transitive(arole(hasDescendant)).
subrole(arole(hasChild), arole(hasDescendant)).
subrole(arole(hasDescendant),arole(hasRelative)).

implies(some(arole(hasRelative), aconcept('Clever')), aconcept('Happy')).

rassertion(arole(hasChild), i11, i12).
rassertion(arole(hasChild), i10, i11).
rassertion(arole(hasChild), i9, i10).
rassertion(arole(hasChild), i8, i9).
rassertion(arole(hasChild), i7, i8).
rassertion(arole(hasChild), i6, i7).
rassertion(arole(hasChild), i5, i6).
rassertion(arole(hasChild), i4, i5).
rassertion(arole(hasChild), i3, i4).
rassertion(arole(hasChild), i2, i3).
rassertion(arole(hasChild), i1, i11).
rassertion(arole(hasChild), i1, i10).
rassertion(arole(hasChild), i1, i9).
rassertion(arole(hasChild), i1, i8).
rassertion(arole(hasChild), i1, i7).
rassertion(arole(hasChild), i1, i6).
rassertion(arole(hasChild), i1, i5).
rassertion(arole(hasChild), i1, i4).
rassertion(arole(hasChild), i1, i3).
rassertion(arole(hasChild), i1, i2).

assertion(aconcept('Clever'), i7).
