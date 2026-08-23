#ifndef DOXTK_TEX_CATCODE_HPP
#define DOXTK_TEX_CATCODE_HPP

/* ========================================================================
 * doxtk_tex_catcode.hpp — TeX category codes for the impl/tex frontend
 *
 * Modelled on TeX82's character tokenizer ("The TeXbook", chapter 7;
 * TeXScrape's tangled source third_party/TeXScrape/TeXSource/TeX.p,
 * sections 207 and 232–236 where the catcode table is declared and
 * initialised by INITEX).
 *
 * TeX assigns every input character a category code ("catcode") in
 * 0..15.  The lexer (the "mouth") consults this table for each
 * character it reads, exactly as TeX's get_next does.  The table is
 * mutable because documents may contain \catcode assignments (e.g.
 * \makeatletter).
 * ======================================================================== */

#include <array>
#include <cstdint>

namespace doxtk {
namespace swaff {
namespace tex {

/* Category codes, in TeX82's numeric order (TeX.p {207:}). */
enum class CatCode : uint8_t {
    Escape      = 0,   /* \  — begins a control sequence            */
    BeginGroup  = 1,   /* {                                       */
    EndGroup    = 2,   /* }                                       */
    MathShift   = 3,   /* $                                       */
    AlignTab    = 4,   /* &                                       */
    EndOfLine   = 5,   /* carriage return / line feed             */
    Parameter   = 6,   /* #                                       */
    Superscript = 7,   /* ^                                       */
    Subscript   = 8,   /* _                                       */
    Ignored     = 9,   /* NUL                                     */
    Space       = 10,  /* space and tab                           */
    Letter      = 11,  /* A..Z a..z                               */
    Other       = 12,  /* everything else                         */
    Active      = 13,  /* ~  — behaves like a control sequence    */
    Comment     = 14,  /* %                                       */
    Invalid     = 15   /* DEL                                     */
};

/* ------------------------------------------------------------------------
 * CatCodeTable
 *
 * A 256-entry array of catcodes with plain-TeX (INITEX) defaults,
 * mirroring the assignments TeX performs before reading any input
 * (TeX.p {232:}–{236:}): everything starts as Other(12), then the
 * special characters are installed.
 * -------------------------------------------------------------------- */

class CatCodeTable {
public:
    CatCodeTable() { reset_plain_tex(); }

    /* INITEX defaults (TeX.p {232:}–{236:}). */
    void reset_plain_tex() {
        table_.fill(CatCode::Other);

        table_[0]   = CatCode::Ignored;     /* NUL          */
        table_[127] = CatCode::Invalid;     /* DEL          */
        table_[9]   = CatCode::Space;       /* tab          */
        table_[32]  = CatCode::Space;       /* space        */
        table_[10]  = CatCode::EndOfLine;   /* LF           */
        table_[13]  = CatCode::EndOfLine;   /* CR           */

        table_[static_cast<uint8_t>('\\')] = CatCode::Escape;
        table_[static_cast<uint8_t>('{')]  = CatCode::BeginGroup;
        table_[static_cast<uint8_t>('}')]  = CatCode::EndGroup;
        table_[static_cast<uint8_t>('$')]  = CatCode::MathShift;
        table_[static_cast<uint8_t>('&')]  = CatCode::AlignTab;
        table_[static_cast<uint8_t>('#')]  = CatCode::Parameter;
        table_[static_cast<uint8_t>('^')]  = CatCode::Superscript;
        table_[static_cast<uint8_t>('_')]  = CatCode::Subscript;
        table_[static_cast<uint8_t>('%')]  = CatCode::Comment;
        table_[static_cast<uint8_t>('~')]  = CatCode::Active;

        for (uint8_t c = 'A'; c <= 'Z'; ++c) table_[c] = CatCode::Letter;
        for (uint8_t c = 'a'; c <= 'z'; ++c) table_[c] = CatCode::Letter;
    }

    CatCode operator[](uint8_t c) const { return table_[c]; }

    CatCode catcode_of(char c) const {
        return table_[static_cast<uint8_t>(c)];
    }

    /* \catcode`<char>=<num> — only values 0..15 are meaningful. */
    bool set(uint8_t c, int code) {
        if (code < 0 || code > 15) return false;
        table_[c] = static_cast<CatCode>(code);
        return true;
    }

    /* \makeatletter / \makeatother (LaTeX idiom). */
    void make_at_letter() { table_[static_cast<uint8_t>('@')] = CatCode::Letter; }
    void make_at_other()  { table_[static_cast<uint8_t>('@')] = CatCode::Other; }

private:
    std::array<CatCode, 256> table_;
};

} // namespace tex
} // namespace swaff
} // namespace doxtk

#endif // DOXTK_TEX_CATCODE_HPP
