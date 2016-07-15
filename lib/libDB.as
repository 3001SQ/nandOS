// -----------------------------------------------------------------------------
// libDB.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// Wrapper for the target database
//
// TODO Integration with memory devices, data links
//
// To get started with nandOS development, check:
// - https://3001sq.net/forums/#/categories/hello-world (Beginners Forum)
// - https://github.com/3001SQ                          (Code Examples)
//

// Binary nandOS API
#include "stdio.h"
#include "time.h"
#include "fcntl.h"

// -----------------------------------------------------------------------------
// Target database, should eventually be streamed from a device
// -----------------------------------------------------------------------------

namespace TargetDatabase
{
// -------------------------------------------------------------------
// -------------------------------------------------------------------

/** Defines structure of target ArmScreenItem data */
enum TargetData
{
	Data_Title = 0,
	Data_Description,
	Data_VesselId,
	Data_Model,
	Data_Comms,
	// ---
	// Additional data?
	// ---
	Data_SIZE
}

// ---------------------------------------------------------

class Entry
{
	string label;
	
	/** Page-specific data for the item displayed on the center screen */
	vector<var> data;
}

// ---------------------------------------------------------

vector<Entry> _data;

uint _activeIndex = 0;

Entry@ AddEntry(string label)
{
	_data.push_back(Entry());
	_data[_data.size() - 1].label = label;
	
	return @_data[_data.size() - 1];
}

Entry@ GetEntry(uint idx)
{
	if (idx < _data.size())
	{
		return @_data[idx];
	}
	else
	{
		return null;
	}
}

size_t GetCount()
{
	return _data.size();
}

void SetActive(uint idx)
{
	if (idx < _data.size())
	{
		_activeIndex = idx;
	}
}

uint GetActiveIndex()
{
	return _activeIndex;
}

/** Return first entry with matching label or -1 if none found */
int FindEntry(string label)
{
	int idx = -1;
	
	for (uint iEntry = 0; iEntry < _data.size(); iEntry++)
	{
		if (_data[iEntry].label == label)
		{
			return int(iEntry);
		}
	}
	
	return idx;
}

// -------------------------------------------------------------------
// -------------------------------------------------------------------
}
