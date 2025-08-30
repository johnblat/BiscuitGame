package game


Handle :: struct {
	idx: u32,
	gen: u32,
}

HANDLE_NONE :: Handle {}


Handle_Array :: struct($T: typeid, $HT: typeid) {
	items: [dynamic]T,
	freelist: [dynamic]HT,
	num: int,
}

ha_clear :: proc(ha: ^Handle_Array($T, $HT)) {
	clear(&ha.items)
	clear(&ha.freelist)
}

ha_delete :: proc(ha: Handle_Array($T, $HT)) {
	delete(ha.items)
	delete(ha.freelist)
}

ha_add :: proc(ha: ^Handle_Array($T, $HT), v: T) -> HT {
	v := v

	if len(ha.freelist) > 0 {
		h := pop(&ha.freelist)
		h.gen += 1
		v.handle = h
		ha.items[h.idx] = v
		ha.num += 1
		return h
	}

	if len(ha.items) == 0 {
		append_nothing(&ha.items) // Item at index zero is always "dummy" used for zero comparison
	}

	idx := u32(len(ha.items))
	v.handle.idx = idx
	v.handle.gen = 1
	append(&ha.items, v)
	ha.num += 1
	return v.handle
}

ha_get :: proc(ha: Handle_Array($T, $HT), h: HT) -> (T, bool) {
	if h.idx > 0 && int(h.idx) < len(ha.items) && ha.items[h.idx].handle == h {
		return ha.items[h.idx], true
	}

	return {}, false
}

ha_get_ptr :: proc(ha: Handle_Array($T, $HT), h: HT) -> ^T {
	if h.idx > 0 && int(h.idx) < len(ha.items) && ha.items[h.idx].handle == h {
		return &ha.items[h.idx]
	}

	return &ha.items[0]
}

ha_remove :: proc(ha: ^Handle_Array($T, $HT), h: HT) {
	if h.idx > 0 && int(h.idx) < len(ha.items) && ha.items[h.idx].handle == h {
		append(&ha.freelist, h)
		ha.items[h.idx] = {}
		ha.num -= 1
	}
}

ha_valid :: proc(ha: Handle_Array($T, $HT), h: HT) -> bool {
	_, ok := ha_get(ha, h)
	return ok
}

// Iterators for iterating over all used
// slots in the array. Used like this:
//
// ent_iter := ha_make_iter(your_handle_based_array)
// for e in ha_iter_ptr(&ent_iter) {
//
// }

Handle_Array_Iter :: struct($T: typeid, $HT: typeid) {
	ha: Handle_Array(T, HT),
	index: int,
}

ha_make_iter :: proc(ha: Handle_Array($T, $HT)) -> Handle_Array_Iter(T, HT) {
	return Handle_Array_Iter(T, HT) { ha = ha }
}

ha_iter :: proc(it: ^Handle_Array_Iter($T, $HT)) -> (val: T, h: HT, cond: bool) {
	in_range := it.index < len(it.ha.items)

	for in_range {
		cond = it.index > 0 && in_range && it.ha.items[it.index].handle.idx > 0

		if cond {
			val = it.ha.items[it.index]
			h = it.ha.items[it.index].handle
			it.index += 1
			return
		}

		it.index += 1
		in_range = it.index < len(it.ha.items)
	}

	return
}

ha_iter_ptr :: proc(it: ^Handle_Array_Iter($T, $HT)) -> (val: ^T, h: HT, cond: bool) {
	in_range := it.index < len(it.ha.items)

	for in_range {
		cond = it.index > 0 && in_range && it.ha.items[it.index].handle.idx > 0

		if cond {
			val = &it.ha.items[it.index]
			h = it.ha.items[it.index].handle
			it.index += 1
			return
		}

		it.index += 1
		in_range = it.index < len(it.ha.items)
	}

	return
}