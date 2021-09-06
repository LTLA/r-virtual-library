/*
 *  R : A Computer Language for Statistical Data Analysis
 *  Copyright (C) 2001-3 Paul Murrell
 *                2003-2019 The R Core Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, a copy is available at
 *  https://www.R-project.org/Licenses/
 */

#include "grid.h"

SEXP L_stroke(SEXP path) 
{
    R_GE_gcontext gc;
    SEXP currentgp;
    /* Get the current device 
     */
    pGEDevDesc dd = getDevice();
    currentgp = gridStateElement(dd, GSS_GPAR);
    gcontextFromgpar(currentgp, 0, &gc, dd);
    
    GEMode(1, dd);
    GEStroke(path, &gc, dd);
    GEMode(0, dd);

    return R_NilValue;
}

SEXP L_fill(SEXP path, SEXP rule) 
{
    R_GE_gcontext gc;
    SEXP currentgp;
    /* Get the current device 
     */
    pGEDevDesc dd = getDevice();
    currentgp = gridStateElement(dd, GSS_GPAR);
    gcontextFromgpar(currentgp, 0, &gc, dd);
    
    GEMode(1, dd);
    GEFill(path, INTEGER(rule)[0], &gc, dd);
    GEMode(0, dd);

    return R_NilValue;
}

SEXP L_fillStroke(SEXP path, SEXP rule) 
{
    R_GE_gcontext gc;
    SEXP currentgp;
    /* Get the current device 
     */
    pGEDevDesc dd = getDevice();
    currentgp = gridStateElement(dd, GSS_GPAR);
    gcontextFromgpar(currentgp, 0, &gc, dd);
    
    GEMode(1, dd);
    GEFillStroke(path, INTEGER(rule)[0], &gc, dd);
    GEMode(0, dd);

    return R_NilValue;
}

