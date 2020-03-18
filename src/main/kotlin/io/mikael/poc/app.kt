package io.mikael.poc

import java.awt.EventQueue
import javax.swing.*

class PocFrame : JFrame() {
    init {
        this.title = "POC"
        defaultCloseOperation = JFrame.EXIT_ON_CLOSE
        setSize(100, 100)
        setLocationRelativeTo(null)
    }
}

object Application {
    @JvmStatic
    fun main(args: Array<String>) {
        EventQueue.invokeLater {
            PocFrame().isVisible = true
        }
    }
}
