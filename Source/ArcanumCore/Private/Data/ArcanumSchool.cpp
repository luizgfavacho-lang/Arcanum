#include "Data/ArcanumSchool.h"
#include "ArcanumGameplayTags.h"

namespace ArcanumSchool
{
	FGameplayTag ToTag(EArcanumSchool School)
	{
		switch (School)
		{
		case EArcanumSchool::Electricity: return ArcanumTags::School_Electricity;
		case EArcanumSchool::Fire:        return ArcanumTags::School_Fire;
		case EArcanumSchool::Energy:      return ArcanumTags::School_Energy;
		case EArcanumSchool::Necromancy:  return ArcanumTags::School_Necromancy;
		case EArcanumSchool::Blood:       return ArcanumTags::School_Blood;
		default:                          return FGameplayTag();
		}
	}

	EArcanumSchool FromTags(const FGameplayTagContainer& Tags)
	{
		if (Tags.HasTagExact(ArcanumTags::School_Electricity)) { return EArcanumSchool::Electricity; }
		if (Tags.HasTagExact(ArcanumTags::School_Fire))        { return EArcanumSchool::Fire; }
		if (Tags.HasTagExact(ArcanumTags::School_Energy))      { return EArcanumSchool::Energy; }
		if (Tags.HasTagExact(ArcanumTags::School_Necromancy))  { return EArcanumSchool::Necromancy; }
		if (Tags.HasTagExact(ArcanumTags::School_Blood))       { return EArcanumSchool::Blood; }
		return EArcanumSchool::None;
	}
}
