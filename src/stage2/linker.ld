ENTRY(stage2_entry)

SECTIONS
{
    . = 0x8000;

    .text : {
        *(.text)
        *(.text.*)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
        *(.note.*)
    }
}