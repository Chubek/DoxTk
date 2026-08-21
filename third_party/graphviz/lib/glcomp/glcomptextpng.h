/*************************************************************************
 * Copyright (c) 2011 AT&T Intellectual Property
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors: Details at https://graphviz.org
 *************************************************************************/

#pragma once

#include <cairo/cairo.h>
#include <pango/pangocairo.h>

/// @param surface [out] A surface used to load the PNG. The caller is
///   responsible for deallocating this with `cairo_surface_destroy` when they
///   are done using the returned pointer.
unsigned char *glCompLoadPng(cairo_surface_t **surface, const char *filename,
                             int *imageWidth, int *imageHeight);
